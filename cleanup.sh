#!/bin/bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
TERRAFORM_CLUSTER_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/clusters/production"
APPLICATION_PLANE_INFRA_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/production/environments"
IAM_USER_NAME="codecommit-user"
ARGOWORKFLOWECR="argoworkflow-container"
APPLICATIONHELMCHARTECR="gitops-saas/helm-tenant-chart"
CONSUMERSERVICEECR="consumer-container"
PRODUCERSERVICEECR="producer-container"
VPC_NAME="eks-saas-gitops"

#delete code-commit user ssh key
user_info=$(aws iam list-ssh-public-keys --user-name "$IAM_USER_NAME" )
key_ids=$(echo "$user_info" | jq -r '.SSHPublicKeys[]?.SSHPublicKeyId')
for key_id in $key_ids; do
     echo "Deleting SSH Key: $key_id"
     aws iam delete-ssh-public-key --user-name "$IAM_USER_NAME" --ssh-public-key-id "$key_id"
done

# remove ecr repos
aws ecr delete-repository --repository-name "$ARGOWORKFLOWECR" --force 
aws ecr delete-repository --repository-name "$APPLICATIONHELMCHARTECR" --force 
aws ecr delete-repository --repository-name "$CONSUMERSERVICEECR" --force 
aws ecr delete-repository --repository-name "$PRODUCERSERVICEECR" --force 

# remove tenant application stack
cd $APPLICATION_PLANE_INFRA_FOLDER || exit 
terraform destroy --auto-approve

# remove s3 state file
aws s3 rm "s3://$TENANT_TERRAFORM_STATE_BUCKET_NAME" --recursive

# remove flux controlled components - to avoid orphaned dependencies
flux suspend hr argo-workflows
helm uninstall argo-workflows -n argo-workflows
flux suspend hr pool-1
helm uninstall pool-1 -n pool-1

#remove security groups created by the ALB ingress resources
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query "Vpcs[0].VpcId" --output text)
security_group_ids=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$vpc_id" --query "SecurityGroups[].GroupId" --output text)
for sg_id in $security_group_ids; do
     echo "Deleting security group $sg_id"
     aws ec2 delete-security-group --group-id "$sg_id"
done

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
     timeout 1800 terraform destroy -var "aws_region=${AWS_REGION}" --auto-approve     

     if [ $? -eq 0 ]; then
          echo "Terraform apply succeeded."    
          SUCCESS=true      
          break
     else
          echo "Terraform apply failed. Retrying..."
          COUNT=$((COUNT+1))
     fi
done

STATUS="SUCCESS"
REASON=""
if [ "$SUCCESS" = false ]; then
     STATUS="FAILED"
     REASON="Failed to delete resources managed by terraform. Go to Cloud9 to delete them manually"
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