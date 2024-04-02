#!/bin/bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --silent)
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
TERRAFORM_FOLDER="/home/ec2-user/environment/workshop/eks-saas-gitops/terraform/workshop" #TODO: make it dynamic
PUB_KEY_FILE_PATH="/home/ec2-user/environment/flux.pub" #TODO: make it dynamic
IAM_USER_NAME="codecommit-user"

ECR_REPOSITORIES=(
    "argoworkflow-container"
    "gitops-saas/helm-tenant-chart"
    "gitops-saas/application-chart"
    "consumer"
    "producer"
    "payments"
    "onboarding_service"
)

delete_flux_managed_resources() {
    # stop flux reconciling from git
    flux delete source git flux-system --silent
    
    # get all helm releases
    RELEASES=$(helm list --all-namespaces --short)
    
    # delete helm releases with flux
    for name in $RELEASES; do
        flux delete helmrelease $name --silent
    done
}

# offboard tenants
delete_flux_managed_resources

# remove flux
flux uninstall -s

#delete code-commit user ssh key
user_info=$(aws iam list-ssh-public-keys --user-name "$IAM_USER_NAME" )
key_ids=$(echo "$user_info" | jq -r '.SSHPublicKeys[]?.SSHPublicKeyId')
for key_id in $key_ids; do
    echo "Deleting SSH Key: $key_id"
    aws iam delete-ssh-public-key --user-name "$IAM_USER_NAME" --ssh-public-key-id "$key_id"
done

# delete ECR repositories
for repo in "${ECR_REPOSITORIES[@]}"; do
    aws ecr delete-repository --repository-name "$repo" --force
done

MAX_RETRIES=3
COUNT=0
SUCCESS=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    cd $TERRAFORM_FOLDER || exit

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
    timeout 1800 terraform destroy \
        -var "aws_region=${AWS_REGION}" \
        -var "public_key_file_path=${PUB_KEY_FILE_PATH}" \
        --auto-approve

    if [ $? -eq 0 ]; then
        echo "Terraform destroy succeeded."    
        SUCCESS=true      
        break
    else
        echo "Terraform destroy failed. Retrying..."
        COUNT=$((COUNT+1))
    fi
done

STATUS="SUCCESS"
REASON=""
if [ "$SUCCESS" = false ]; then
    STATUS="FAILED"
    REASON="Failed to delete resources managed by terraform. Please go to Cloud9 to delete them manually"
fi

#get cfn parameter from ssm
CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

#remove ssm parameter
aws ssm delete-parameter --name "eks-saas-gitops-custom-resource-event"

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