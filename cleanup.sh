#!/bin/bash
set -e
trap 'catch_error $? $LINENO' ERR

catch_error() {     
     #get cfn parameter from ssm
     CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

     STATUS="FAILURE"
     EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
     EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
     EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
     EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

     JSON_DATA='{
          "Status": "'"$STATUS"'",
          "Reason": "Error "'"$1"'" occurred on "'"$2"'",
          "StackId": "'"$EVENT_STACK_ID"'",
          "PhysicalResourceId": "Terraform",
          "RequestId": "'"$EVENT_REQUEST_ID"'",
          "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
     }'

     # Send the JSON data using curl
     curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"          
}

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
export TERRAFORM_CLUSTER_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/clusters/production"
export APPLICATION_PLANE_INFRA_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/production/environments"

cd $APPLICATION_PLANE_INFRA_FOLDER || exit 
terraform destroy --auto-approve

MAX_RETRIES=3
COUNT=0
SUCCESS=false

while [ $COUNT -lt $MAX_RETRIES ]; do
     cd $TERRAFORM_CLUSTER_FOLDER || exit

     # get terminating namespaces
     terminating_namespaces=$(kubectl get namespaces --field-selector status.phase=Terminating -o json | jq -r '.items[].metadata.name')

     # If there are no terminating namespaces, exit the script
     if [[ -z $terminating_namespaces ]]; then
          echo "No terminating namespaces found"
     fi

     #force terminate namespaces
     for ns in $terminating_namespaces; do
          echo "Terminating namespace: $ns"
          kubectl get namespace $ns -o json | sed 's/"kubernetes"//' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
     done

     #run destroy again
     timeout 1200 terraform destroy -var "aws_region=${AWS_REGION}" --auto-approve     

     if [ $? -eq 0 ]; then
          echo "Terraform apply succeeded."    
          SUCCESS=true      
          break
     else
          echo "Terraform apply failed. Retrying..."
          COUNT=$((COUNT+1))
     fi
done

#get cfn parameter from ssm
CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

STATUS="SUCCESS"
REASON=""
if [ "$SUCCESS" = false ]; then
     STATUS="FAILURE"
     REASON="Failed to delete resource managed by terraform. Go to Cloud9 to delete them manually"
fi

#set variables
EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

JSON_DATA='{
     "Status": "'"$STATUS"'",
     "Reason": "'"$REASON"'",
     "StackId": "'"$EVENT_STACK_ID"'",
     "PhysicalResourceId": "Terraform",
     "RequestId": "'"$EVENT_REQUEST_ID"'",
     "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
}'

# Send the JSON data using curl
curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"