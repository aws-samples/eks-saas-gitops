#!/bin/bash
set -e

TERRAFORM_DIR="workshop"

echo "Starting installation..."

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
}

# Initialize and apply terraform
deploy_terraform() {
    cd "$TERRAFORM_DIR"
    echo "Initializing Terraform..."
    terraform init

    echo "Planning Terraform deployment..."
    terraform plan

    echo "Applying Terraform configuration..."
    terraform apply --auto-approve

    GITEA_PASSWORD=$(aws ssm get-parameter \
        --name '/eks-saas-gitops/gitea-admin-password' \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text)

    GITEA_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
}

# Print the setup information
print_setup_info() {
    echo "=============================="
    echo "Installation Complete!"
    echo "=============================="
    echo "Gitea URL: http://${GITEA_IP}:3000"
    echo "Gitea Admin Username: admin"
    echo "Gitea Admin Password: ${GITEA_PASSWORD}"
    echo ""
    echo "=============================="
}

# Main execution
main() {
    check_prerequisites
    deploy_terraform
    print_setup_info
}

# Run the script
main
