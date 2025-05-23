#!/bin/bash
set -e

TERRAFORM_DIR="workshop"

echo "Starting infrastructure destruction..."

# Change to the terraform workshop directory
cd "$TERRAFORM_DIR"

# First, ensure the Gitea token is available in Terraform state
echo "Retrieving Gitea token into Terraform state..."
terraform apply --target data.aws_ssm_parameter.gitea_token --auto-approve

# Skip provider verification since Gitea server will be destroyed
export TF_SKIP_PROVIDER_VERIFY=1

# Get AWS region
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo ${AWS_REGION:-$(aws configure get region)})

# Clean up ECR repositories
echo "Cleaning up ECR repositories..."
for repo in $(aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output text); do
    echo "Deleting images from $repo..."
    # Delete all images in repository
    aws ecr batch-delete-image \
        --repository-name "$repo" \
        --image-ids "$(aws ecr list-images --repository-name "$repo" --query 'imageIds[*]' --output json)" \
        --region $AWS_REGION || true
done

# Get VPC and IGW information
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [ -n "$VPC_ID" ]; then
    # First terminate any EC2 instances in the VPC
    echo "Finding and terminating EC2 instances in VPC $VPC_ID..."
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped,pending,stopping" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text \
        --region $AWS_REGION)
    
    if [ -n "$INSTANCE_IDS" ]; then
        echo "Terminating instances: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $AWS_REGION
        
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $AWS_REGION
    fi

    # Then try to detach the IGW
    echo "Finding and detaching Internet Gateway from VPC $VPC_ID..."
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text)
    
    if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
        echo "Detaching Internet Gateway $IGW_ID..."
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "$IGW_ID" \
            --vpc-id "$VPC_ID"
        echo "Internet Gateway detached successfully"
    fi
fi

# Run terraform destroy
echo "Running terraform destroy..."
terraform destroy -auto-approve

echo "Infrastructure destruction completed."
