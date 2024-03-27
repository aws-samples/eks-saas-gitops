from flask import Flask
from flask import request
from threading import Thread
from datetime import datetime
import os
import boto3
import logging
import sys
import pytz

app = Flask(__name__)
logger = logging.getLogger("consumer")
logger.setLevel(logging.INFO)
logging.basicConfig(stream=sys.stdout)

sts_client = boto3.client('sts')
ssm_client = boto3.client("ssm")
sqs_client = boto3.client("sqs")
ddb_client = boto3.client("dynamodb")
sms_queue_param_name_suffix = "consumer_sqs"
sms_ddb_param_name_suffix = "consumer_ddb"

environment = os.environ.get("ENVIRONMENT")
service_name = "consumer"
ms_version = "0.0.1"
max_messages_to_read = 10
wait_time_seconds = 20


def get_queue_url(environment):
    response = ssm_client.get_parameter(Name=f"/{environment}/{sms_queue_param_name_suffix}")
    parts = response["Parameter"]["Value"].split(":")
    aws_region = parts[3]
    aws_account_id = parts[4]
    queue_name = parts[5].split("/")[-1]
    queue_url = f"https://sqs.{aws_region}.amazonaws.com/{aws_account_id}/{queue_name}"
    return queue_url


def get_ddb_table_name(environment):
    response = ssm_client.get_parameter(Name=f"/{environment}/{sms_ddb_param_name_suffix}")
    parts = response["Parameter"]["Value"].split(":")
    table_name = parts[5].split("/")[-1]
    return table_name


@app.route("/consumer", methods = ['GET'])
def index():    
    tenant_id = request.headers.get("tenantID")
    return {
        "tenant_id": tenant_id, 
        "environment": environment, 
        "version": ms_version, 
        "microservice": service_name 
    }


@app.route("/consumer/readiness-probe", methods = ['GET'])
def index():    
    try:
        sts_client.get_caller_identity()        
        
        # Ready, lets start the thread to process messages.
        Thread(target = process_messages).start()
        
        return { "Status": "OK" }
        
    except Exception as e:
        return { "Status": "NotReady" }, 500


def receive_message_from_sqs(queue_url, max_messages=5):
    response = sqs_client.receive_message(
        QueueUrl=queue_url,
        AttributeNames=["All"],
        MessageAttributeNames=["All"],
        WaitTimeSeconds=wait_time_seconds,
        MaxNumberOfMessages=max_messages
    )    
    return response.get("Messages", [])


def get_utc_timestamp_string():        
    current_time = datetime.now(pytz.timezone("UTC"))
    return current_time.strftime("%Y-%m-%dT%H:%M:%S%z")


def process_messages():    
    sqs_queue_url = get_queue_url(environment)
    ddb_table_name = get_ddb_table_name(environment)
    while True:
        try:
            logger.info(f"Searching for messages on queue: {sqs_queue_url}")
            messages = receive_message_from_sqs(sqs_queue_url, max_messages=max_messages_to_read)
            
            for message in messages:
                message_attributes = message["MessageAttributes"]
                message_id = message["MessageId"]
                tenant_id = message_attributes["tenant_id"]["StringValue"]                
                producer_env = message_attributes["producer_environment"]["StringValue"]                
                
                ddb_client.put_item(
                    Item={
                        "tenant_id": {
                            "S": tenant_id
                        },
                        "message_id": {
                            "S": message_id,
                        },
                        "producer_environment": {
                            "S": producer_env,
                        },
                        "consumer_environment": {
                            "S": environment,
                        },
                        "timestamp": {
                            "S": get_utc_timestamp_string(),
                        },
                    },
                    TableName=ddb_table_name,
                )
                logger.info(f"Message [{message_id}] persisted in DDB table: {ddb_table_name}")                
                
                sqs_client.delete_message(QueueUrl=sqs_queue_url, ReceiptHandle=message["ReceiptHandle"])                                        
                logger.info(f"Message [{message_id}] deleted from queue {sqs_queue_url}")
        except Exception as e:
            logger.error("Exception raised! " + str(e))        


if __name__ == "__main__":        
    # run in 0.0.0.0 so that it can be accessed from outside the container
    app.run(host="0.0.0.0", port=80)