#!/bin/bash
set -e
trap 'catch_error $? $LINENO' ERR
touch /home/ec2-user/environment/install_errors.txt

catch_error() {
     echo "Error $1 occurred on $2" >> /home/ec2-user/environment/install_errors.txt
     #send response back to cloudformation
     export JSON_DATA="{
          \"Status\" : \"FAILED\",
          \"Reason\" : \"Error $1 occurred on $2\",
          \"StackId\" : \"$EVENT_STACK_ID\",
          \"PhysicalResourceId\" : \"$PHYSICAL_RESOURCE_ID\",
          \"RequestId\" : \"$EVENT_REQUEST_ID\",
          \"LogicalResourceId\" : \"$EVENT_LOGICAL_RESOURCE_ID\"
     }"
     curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"
}

# TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
# AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
# export TERRAFORM_CLUSTER_FOLDER="/home/ec2-user/environment/eks-saas-gitops/terraform/clusters/production"
# export APPLICATION_PLANE_INFRA_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/production/environments"

# cd $TERRAFORM_CLUSTER_FOLDER || exit
# terraform destroy -var "aws_region=${AWS_REGION}" --auto-approve -force

# cd $APPLICATION_PLANE_INFRA_FOLDER || exit 
# terraform destroy --auto-approve

export JSON_DATA="{
     \"Status\" : \"SUCCESS\",
     \"Reason\" : \"clean up completed\",
     \"StackId\" : \"$EVENT_STACK_ID\",
     \"PhysicalResourceId\" : \"$PHYSICAL_RESOURCE_ID\",
     \"RequestId\" : \"$EVENT_REQUEST_ID\",
     \"LogicalResourceId\" : \"$EVENT_LOGICAL_RESOURCE_ID\"
}"

curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"