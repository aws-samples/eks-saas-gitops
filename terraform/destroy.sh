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
    echo "Finding and detaching Internet Gateway from VPC $VPC_ID..."
    IGW_ID=$(aws ecr describe-internet-gateways \
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
