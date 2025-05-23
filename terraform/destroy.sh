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
    aws ecr batch-delete-image \
        --repository-name "$repo" \
        --image-ids "$(aws ecr list-images --repository-name "$repo" --query 'imageIds[*]' --output json)" \
        --region $AWS_REGION || true
done

echo "Destroying resources in specific order..."

# First destroy EKS node groups
echo "Destroying EKS node groups..."
terraform destroy -target=module.eks.aws_eks_node_group.managed_ng -auto-approve || true

# Then destroy EKS cluster
echo "Destroying EKS cluster..."
terraform destroy -target=module.eks -auto-approve || true

# Then destroy VPC
echo "Destroying VPC and related resources..."
terraform destroy -target=module.vpc -auto-approve || true

# Finally, attempt to destroy everything else
echo "Running final terraform destroy..."
terraform destroy -auto-approve

echo "Infrastructure destruction completed."
