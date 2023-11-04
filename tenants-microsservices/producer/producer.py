from flask import Flask
from flask import request
from flask import jsonify
import boto3
import os
import logging

app = Flask(__name__)
app.logger.setLevel(logging.DEBUG)

ssm_client = boto3.client("ssm")
sqs_client = boto3.client("sqs")
sms_queue_param_name_suffix = "producer_sqs"

environment = os.environ.get("ENVIRONMENT")
service_name = "producer"
ms_version = "0.0.1"


def get_queue_url(tenant_id):
    response = ssm_client.get_parameter(Name=f"/{tenant_id}/{sms_queue_param_name_suffix}")
    parts = response["Parameter"]["Value"].split(":")    
    aws_region = parts[3]
    aws_account_id = parts[4]
    queue_name = parts[5].split("/")[-1]
    queue_url = f"https://sqs.{aws_region}.amazonaws.com/{aws_account_id}/{queue_name}"    
    return queue_url


@app.route("/producer/version")
def version():
    tenant_id = request.headers.get("tenantID")
    message = { 
        "tenant_id": tenant_id, 
        "environment": environment, 
        "version": ms_version, 
        "microservice": service_name,            
    }
    return jsonify(message)


@app.route("/producer")
def index():
    try:
        tenant_id = request.headers.get("tenantID")

        if (tenant_id is None):
            return { "msg": "NotFound" }, 404
        
        response = sqs_client.send_message(
            QueueUrl=get_queue_url(tenant_id),
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
        return jsonify(message)
    
    except Exception as e:
        app.logger.error("Exception raised! " + str(e))
        return { "msg": "Oops - please check application logs" }, 500


if __name__ == "__main__":
    # run in 0.0.0.0 so that it can be accessed from outside the container
    app.run(host="0.0.0.0", port=80)