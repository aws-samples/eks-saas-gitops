#!/bin/bash
set -e

TERRAFORM_DIR="workshop"

echo "Starting infrastructure-only installation..."

# Check if required tools are installed
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null
    then
        echo "Terraform is not installed. Please install Terraform first."
        exit 1
    fi

    if ! command -v aws &> /dev/null
    then
        echo "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi

    if [ ! -d "$TERRAFORM_DIR" ]
    then
        echo "Terraform directory '$TERRAFORM_DIR' not found!"
        exit 1
    fi
    
    # Define the repository root directory
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "Repository root: ${REPO_ROOT}"
}

# Initialize and apply terraform for infrastructure components only
deploy_terraform_infra() {
    cd "$TERRAFORM_DIR"
    echo "Initializing Terraform..."
    terraform init

    echo "Planning Terraform deployment (infrastructure only)..."
    terraform plan -target=module.vpc \
                  -target=module.ebs_csi_irsa_role \
                  -target=module.image_automation_irsa_role \
                  -target=module.eks \
                  -target=random_password.gitea_admin \
                  -target=aws_ssm_parameter.gitea_password \
                  -target=module.gitea \
                  -target=aws_vpc_peering_connection.vscode_to_gitea \
                  -target=aws_route.vscode_to_gitea \
                  -target=aws_route.gitea_to_vscode

    echo "Applying Terraform configuration (infrastructure only)..."
    terraform apply -target=module.vpc \
                   -target=module.ebs_csi_irsa_role \
                   -target=module.image_automation_irsa_role \
                   -target=module.eks \
                   -target=random_password.gitea_admin \
                   -target=aws_ssm_parameter.gitea_password \
                   -target=module.gitea \
                   -target=aws_vpc_peering_connection.vscode_to_gitea \
                   -target=aws_route.vscode_to_gitea \
                   -target=aws_route.gitea_to_vscode \
                   -target=kubernetes_namespace.flux_system \
                   --auto-approve

    # Retrieve Gitea information after successful deployment
    GITEA_PASSWORD=$(aws ssm get-parameter \
        --name '/eks-saas-gitops/gitea-admin-password' \
        --with-decryption \
        --query 'Parameter.Value' \
        --region $(terraform output -raw aws_region) \
        --output text)

    # Get both public and private IPs - only for RUNNING instances
    GITEA_PUBLIC_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --region $(terraform output -raw aws_region) \
        --output text)

    GITEA_PRIVATE_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --region $(terraform output -raw aws_region) \
        --output text)

    echo "Gitea server public IP: ${GITEA_PUBLIC_IP}"
    echo "Gitea server private IP: ${GITEA_PRIVATE_IP}"
    
    # Ensure we have a valid IP before proceeding
    if [ -z "$GITEA_PRIVATE_IP" ] || [ "$GITEA_PRIVATE_IP" == "None" ] || [ "$GITEA_PRIVATE_IP" == "null" ]; then
        echo "ERROR: Could not determine Gitea private IP address. Please check if the Gitea instance is running."
        exit 1
    fi
        
    # Get the AWS region from Terraform or environment variable
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo ${AWS_REGION:-$(aws configure get region)})
    
    # Configure kubectl to connect to the new cluster with explicit region
    if [ -n "$AWS_REGION" ]; then
        echo "Configuring kubectl for region: $AWS_REGION"
        aws eks update-kubeconfig --name eks-saas-gitops --region "$AWS_REGION"
    else
        echo "ERROR: Could not determine AWS region. Please set AWS_REGION environment variable."
        exit 1
    fi
}

# Create Gitea repositories
create_gitea_repositories() {
    echo "Creating Gitea repositories..."
    
    # Apply the Gitea repository resources
    terraform apply -target=gitea_repository.eks-saas-gitops -target=gitea_repository.producer -target=gitea_repository.consumer -target=gitea_repository.payments --auto-approve
    
    echo "Gitea repositories created successfully!"
}

# Apply Flux and GitOps infrastructure
apply_flux() {
    echo "Applying GitOps infrastructure and Flux..."
    terraform apply -target=module.gitops_saas_infra -target=kubernetes_config_map.saas_infra_outputs --auto-approve
    terraform apply -target=null_resource.execute_templating_script --auto-approve
    terraform apply -target=module.flux_v2 --auto-approve

    echo "Flux and GitOps infrastructure applied successfully."
}

# Print the setup information
print_setup_info() {
    echo "=============================="
    echo "Infrastructure Installation Complete!"
    echo "=============================="
    echo "Gitea URL: http://${GITEA_PUBLIC_IP}:3000"
    echo "Gitea Admin Username: admin"
    echo "Gitea Admin Password: ${GITEA_PASSWORD}"
    echo ""
    echo "Your EKS cluster has been configured."
    echo "=============================="
}

# Main execution
main() {
    check_prerequisites
    deploy_terraform_infra
    create_gitea_repositories  # Create Gitea repositories
    echo "Proceeding with Flux setup..."
    apply_flux
    echo "=============================="
    echo "Flux Setup Complete!"
    echo "=============================="
    echo "You can now check the status of Flux with:"
    echo "kubectl get pods -n flux-system"
    echo "=============================="
    print_setup_info
}

# Run the script
main
