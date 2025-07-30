#!/bin/bash
set -e

# Accept AWS region as parameter
AWS_REGION=${1:-$(aws configure get region)}
export AWS_REGION

# Get the allowed IP from CloudFormation parameter (if available)
ALLOWED_IP=${2:-""}
export ALLOWED_IP

TERRAFORM_DIR="workshop"

echo "Starting infrastructure-only installation in region: ${AWS_REGION}..."
echo "Using allowed IP for Gitea access: ${ALLOWED_IP}"

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
    export REPO_ROOT
    echo "Repository root: ${REPO_ROOT}"
}

# Initialize and apply terraform for infrastructure components only
deploy_terraform_infra() {
    cd "$TERRAFORM_DIR"
    echo "Initializing Terraform..."
    terraform init

    echo "Planning Terraform deployment (infrastructure only) in region: ${AWS_REGION}..."
    # Pass AWS region as a variable to Terraform
    export TF_VAR_aws_region="${AWS_REGION}"
    export TF_VAR_allowed_ip="${ALLOWED_IP}"
    
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
        --region "${AWS_REGION}" \
        --output text)

    # Get both public and private IPs - only for RUNNING instances
    GITEA_PUBLIC_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --region "${AWS_REGION}" \
        --output text)

    GITEA_PRIVATE_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --region "${AWS_REGION}" \
        --output text)

    echo "Gitea server public IP: ${GITEA_PUBLIC_IP}"
    echo "Gitea server private IP: ${GITEA_PRIVATE_IP}"
    
    # Ensure we have a valid IP before proceeding
    if [ -z "$GITEA_PRIVATE_IP" ] || [ "$GITEA_PRIVATE_IP" == "None" ] || [ "$GITEA_PRIVATE_IP" == "null" ]; then
        echo "ERROR: Could not determine Gitea private IP address. Please check if the Gitea instance is running."
        exit 1
    fi
        
    # Configure kubectl to connect to the new cluster with explicit region
    echo "Configuring kubectl for region: $AWS_REGION"
    aws eks update-kubeconfig --name eks-saas-gitops --region "$AWS_REGION"
}

# Create Gitea repositories
create_gitea_repositories() {
    echo "Creating Gitea repositories..."
    
    # Apply the Gitea repository resources
    terraform apply -target=data.aws_ssm_parameter.gitea_token --auto-approve
    terraform apply -target=gitea_repository.eks-saas-gitops --auto-approve
    
    echo "Gitea repositories created successfully!"
}

# Apply Flux and GitOps infrastructure
apply_flux() {
    echo "Applying GitOps infrastructure and Flux..."
    terraform apply -target=module.gitops_saas_infra -target=kubernetes_config_map.saas_infra_outputs --auto-approve
    terraform apply -target=null_resource.execute_templating_script --auto-approve
    terraform apply -target=null_resource.execute_setup_repos_script --auto-approve
    terraform apply -target=module.flux_v2 --auto-approve
    
    sleep 120
    bash quick_fix_flux.sh

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

# Clone Gitea repositories
clone_gitea_repos() {
    echo "Cloning Gitea repositories..."
    
    # Get Gitea token from SSM
    GITEA_TOKEN=$(aws ssm get-parameter \
        --name "/eks-saas-gitops/gitea-flux-token" \
        --with-decryption \
        --query 'Parameter.Value' \
        --region "${AWS_REGION}" \
        --output text)

    # Create temporary directory for cloning
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"

    # Clone the repository
    echo "Cloning eks-saas-gitops repository..."
    git clone "http://admin:${GITEA_TOKEN}@${GITEA_PRIVATE_IP}:3000/admin/eks-saas-gitops.git"
    
    
    cd "${REPO_ROOT}"
    cp -r "${TEMP_DIR}/eks-saas-gitops" ../gitops-gitea-repo
    
    # Clean up
    rm -rf "${TEMP_DIR}"
    
    echo "Repository cloning completed successfully!"

    echo "Moving eks-saas-gitops up one level"
    cd "${REPO_ROOT}/.."
    mv eks-saas-gitops ../
    
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
    clone_gitea_repos
}

# Run the script
main
