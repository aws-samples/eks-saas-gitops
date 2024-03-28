from flask import Flask
from flask import request
import boto3
import os
import logging

app = Flask(__name__)
app.logger.setLevel(logging.DEBUG)

sts_client = boto3.client('sts')
ssm_client = boto3.client("ssm")
sqs_client = boto3.client("sqs")
sms_queue_param_name_suffix = "consumer_sqs"

environment = os.environ.get("ENVIRONMENT")
service_name = "producer"
ms_version = "0.0.1"


def get_queue_url(tenant_id, tier):
    # basic tier uses pool environment parameters, otherwise tenant specific
    env_id = environment if tier == "basic" else tenant_id
    
    response = ssm_client.get_parameter(Name=f"/{env_id}/{sms_queue_param_name_suffix}")
    parts = response["Parameter"]["Value"].split(":")
    aws_region = parts[3]
    aws_account_id = parts[4]
    queue_name = parts[5].split("/")[-1]
    queue_url = f"https://sqs.{aws_region}.amazonaws.com/{aws_account_id}/{queue_name}"    
    return queue_url


@app.route("/producer/readiness-probe", methods = ['GET'])
def probe():    
    try:
        sts_client.get_caller_identity()                
        return { "Status": "OK" }
    except Exception as e:
        return { "Status": "NotReady" }, 500


@app.route("/producer", methods = ['GET'])
def get():
    tenant_id = request.headers.get("tenantID")
    return { 
        "tenant_id": tenant_id, 
        "environment": environment, 
        "version": ms_version, 
        "microservice": service_name,            
    }    


@app.route("/producer", methods = ['POST'])
def post():
    try:
        tenant_id = request.headers.get("tenantID")
        tier = request.headers.get("tier", default="basic")

        if (tier not in ["basic", "advanced", "premium"]):
            return { "msg": "BadRequest: invalid tier" }, 400

        if (tenant_id is None):
            return { "msg": "NotFound" }, 404
        
        response = sqs_client.send_message(
            QueueUrl=get_queue_url(tenant_id, tier),
            MessageAttributes={
                "tenant_id": {
                    "StringValue": tenant_id,
                    "DataType": "String"
                },
                "producer_environment": {
                    "StringValue": environment,
                    "DataType": "String"
                },                
            },
            MessageBody=str({ "event": "Event raised!" })
        )

        message = { 
            "tenant_id": tenant_id, 
            "environment": environment, 
            "version": ms_version, 
            "microservice": service_name,
            "message_id": response["MessageId"]
        }
        app.logger.info(f"Message produced: {message}")
        return message
    
    except Exception as e:
        app.logger.error("Exception raised! " + str(e))
        return { "msg": "Oops - please check application logs" }, 500


if __name__ == "__main__":
    # run in 0.0.0.0 so that it can be accessed from outside the container
    app.run(host="0.0.0.0", port=80)