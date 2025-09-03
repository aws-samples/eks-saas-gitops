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

# Backup and remove Gitea provider and resources
echo "Removing Gitea provider and resources from Terraform configuration..."
cp providers.tf providers.tf.backup
cp main.tf main.tf.backup
cp versions.tf versions.tf.backup
cp saas_gitops.tf saas_gitops.tf.backup

# Remove Gitea provider from providers.tf
sed -i '/^provider "gitea"/,/^}/d' providers.tf
# Remove gitea from required_providers block in versions.tf
sed -i '/gitea = {/,/}/d' versions.tf

# Remove Gitea resources from main.tf (gitea_repository and related data sources)
sed -i '/^resource "gitea_repository" "eks-saas-gitops"/,/^}/d' main.tf
sed -i '/^data "aws_ssm_parameter" "gitea_token"/,/^}/d' main.tf

# Comment out the entire flux module and gitea data source in saas_gitops.tf
sed -i '/^data "aws_ssm_parameter" "gitea_flux_token"/,/^}/s/^/# /' saas_gitops.tf
sed -i '/^module "flux_v2"/,/^}/s/^/# /' saas_gitops.tf
# Also comment out gitea references in the configmap
sed -i '/gitea_token.*=/s/^/    # /' saas_gitops.tf

# Remove gitea and flux resources from terraform state
echo "Removing gitea and flux resources from terraform state..."
terraform state rm 'gitea_repository.eks-saas-gitops' 2>/dev/null || true
terraform state rm 'data.aws_ssm_parameter.gitea_token' 2>/dev/null || true
terraform state rm 'kubernetes_namespace.flux_system' 2>/dev/null || true

# Reinitialize terraform without gitea provider
echo "Reinitializing terraform without gitea provider..."
rm -f .terraform.lock.hcl
terraform init

# Skip provider verification since Gitea server will be destroyed
export TF_SKIP_PROVIDER_VERIFY=1

# Clean up ECR repositories
echo "Cleaning up ECR repositories..."
for repo in $(aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output text 2>/dev/null || echo ""); do
    if [ -n "$repo" ]; then
        echo "Deleting images from $repo..."
        aws ecr batch-delete-image \
            --repository-name "$repo" \
            --image-ids "$(aws ecr list-images --repository-name "$repo" --query 'imageIds[*]' --output json)" \
            --region $AWS_REGION || true
    fi
done

# Clean up load balancers with eks-saas-gitops tag
echo "Cleaning up load balancers with eks-saas-gitops tag..."
# Clean up Application/Network Load Balancers (ELBv2)
for lb_arn in $(aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || echo ""); do
    if [ -n "$lb_arn" ] && aws elbv2 describe-tags --resource-arns "$lb_arn" --region $AWS_REGION --query 'TagDescriptions[0].Tags[?contains(Key, `eks-saas-gitops`) || contains(Value, `eks-saas-gitops`) || Key == `kubernetes.io/cluster/eks-saas-gitops`]' --output text | grep -q .; then
        echo "Deleting ALB/NLB: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $AWS_REGION || true
    fi
done
# Clean up Classic Load Balancers (ELB)
for lb_name in $(aws elb describe-load-balancers --region $AWS_REGION --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null || echo ""); do
    if [ -n "$lb_name" ] && aws elb describe-tags --load-balancer-names "$lb_name" --region $AWS_REGION --query 'TagDescriptions[0].Tags[?Key==`kubernetes.io/cluster/eks-saas-gitops`]' --output text | grep -q .; then
        echo "Deleting classic load balancer: $lb_name"
        aws elb delete-load-balancer --load-balancer-name "$lb_name" --region $AWS_REGION || true
    fi
done

# Clean up remaining ENIs in VPC
echo "Cleaning up remaining ENIs..."
for vpc_id in $(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=eks-saas-gitops" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo ""); do
    if [ -n "$vpc_id" ]; then
        for eni_id in $(aws ec2 describe-network-interfaces --region $AWS_REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null || echo ""); do
            if [ -n "$eni_id" ]; then
                echo "Deleting ENI: $eni_id"
                aws ec2 delete-network-interface --network-interface-id "$eni_id" --region $AWS_REGION || true
            fi
        done
    fi
done

# Wait for cleanup
echo "Waiting for cleanup to complete..."
sleep 30

# Run single terraform destroy
echo "Running terraform destroy..."
terraform destroy -auto-approve

# Restore original files
echo "Restoring original Terraform files..."
mv providers.tf.backup providers.tf
mv main.tf.backup main.tf
mv versions.tf.backup versions.tf
mv saas_gitops.tf.backup saas_gitops.tf

echo "Infrastructure destruction completed."