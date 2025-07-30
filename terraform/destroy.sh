#!/bin/bash
set -e

# Accept AWS region as parameter
AWS_REGION=${1:-$(aws configure get region)}
export AWS_REGION

TERRAFORM_DIR="workshop"

echo "Starting infrastructure destruction in region: ${AWS_REGION}..."

# Change to the terraform workshop directory
cd "$TERRAFORM_DIR"

# Set terraform variables
export TF_VAR_aws_region="${AWS_REGION}"

# First, ensure the Gitea token is available in Terraform state
echo "Retrieving Gitea token into Terraform state..."
terraform apply --target data.aws_ssm_parameter.gitea_token --auto-approve

# Skip provider verification since Gitea server will be destroyed
export TF_SKIP_PROVIDER_VERIFY=1

# Force remove flux-system namespace if it's stuck
echo "Checking for stuck flux-system namespace..."
if kubectl get namespace flux-system 2>/dev/null; then
    echo "Removing finalizers from flux-system namespace..."
    kubectl get namespace flux-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/flux-system/finalize" -f - || true
    echo "Waiting for namespace cleanup..."
    sleep 30
fi

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

# First destroy EKS node groups with multiple attempts
echo "Destroying EKS node groups..."
for i in {1..3}; do
    echo "Attempt $i to destroy EKS node groups..."
    terraform destroy -target=module.eks.aws_eks_node_group.managed_ng -auto-approve && break || {
        echo "Node group destroy failed, waiting 60 seconds before retry..."
        sleep 60
    }
done

# Wait for node groups to be fully deleted
echo "Waiting for node groups to be fully deleted..."
sleep 60

# Then destroy EKS cluster
echo "Destroying EKS cluster..."
terraform destroy -target=module.eks -auto-approve || true

# Then destroy VPC
echo "Destroying VPC and related resources..."
terraform destroy -target=module.vpc -auto-approve || true

# Clean up IAM roles that might prevent reprovisioning
echo "Destroying IAM roles..."
terraform destroy -target=module.ebs_csi_irsa_role -auto-approve || true
terraform destroy -target=module.image_automation_irsa_role -auto-approve || true
terraform destroy -target=module.gitops_saas_infra -auto-approve || true

# Finally, attempt to destroy everything else
echo "Running final terraform destroy..."
terraform destroy -auto-approve

echo "Infrastructure destruction completed."
