#!/bin/bash
set -e


echo "Starting infrastructure destruction..."

# Get the AWS region from environment variable or AWS CLI configuration
AWS_REGION=${AWS_REGION:-$(aws configure get region)}
cd "workshop"

# First, ensure the Gitea token is available in Terraform state
echo "Retrieving Gitea token into Terraform state..."
terraform apply --target data.aws_ssm_parameter.gitea_token --auto-approve || true

# Skip provider verification to avoid Gitea connection issues during destroy
export TF_SKIP_PROVIDER_VERIFY=1

# Find and terminate EC2 instances in the VPC
echo "Finding EC2 instances in the VPC..."
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")

if [ -n "$VPC_ID" ]; then
  echo "Finding and terminating EC2 instances in VPC $VPC_ID..."
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped,pending,stopping" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --region "$AWS_REGION")
  
  if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
    
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
  else
    echo "No instances found in the VPC."
  fi
  
  # Release any Elastic IPs
  echo "Releasing any unassociated Elastic IPs..."
  ALLOCATION_IDS=$(aws ec2 describe-addresses \
    --query "Addresses[?AssociationId==null].AllocationId" \
    --output text \
    --region "$AWS_REGION")
  
  if [ -n "$ALLOCATION_IDS" ]; then
    for ALLOCATION_ID in $ALLOCATION_IDS; do
      echo "Releasing Elastic IP $ALLOCATION_ID"
      aws ec2 release-address --allocation-id $ALLOCATION_ID --region "$AWS_REGION"
    done
  else
    echo "No unassociated Elastic IPs found."
  fi
else
  echo "Could not determine VPC ID. Skipping EC2 instance termination."
fi

# Run terraform destroy with increased timeout
echo "Running terraform destroy..."
terraform destroy -auto-approve -parallelism=10 || true

# Check if there are still resources and try to destroy specific resources first
if terraform state list &>/dev/null; then
  echo "Some resources still exist. Trying targeted destruction..."
  
  # Try to destroy EKS resources first
  terraform destroy -target=module.eks -auto-approve || true
  
  # Try to destroy Gitea resources
  terraform destroy -target=module.gitea -auto-approve || true
  
  # Try to destroy VPC peering connections
  terraform destroy -target="aws_vpc_peering_connection.vscode_to_gitea" -auto-approve || true
  
  # Try to destroy routes
  terraform destroy -target="aws_route.vscode_to_gitea" -target="aws_route.gitea_to_vscode" -auto-approve || true
  
  # Try to destroy VPC last
  terraform destroy -target=module.vpc -auto-approve || true
  
  # Final destroy attempt
  terraform destroy -auto-approve
fi

echo "Infrastructure destruction completed."
