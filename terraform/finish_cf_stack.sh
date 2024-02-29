#!/bin/bash
# This script is used for AWS Provisioned environments only
# Get cfn parameter from ssm created by Lambda function
CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

#set variables
STATUS="SUCCESS"
EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

JSON_DATA='{
     "Status": "'"$STATUS"'",
     "Reason": "Terraform executed successfully from Cloud9",
     "StackId": "'"$EVENT_STACK_ID"'",
     "PhysicalResourceId": "Terraform",
     "RequestId": "'"$EVENT_REQUEST_ID"'",
     "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
}'

# Send the JSON data using curl
curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"