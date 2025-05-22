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
        --output text)

    # Get both public and private IPs - only for RUNNING instances
    GITEA_PUBLIC_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    GITEA_PRIVATE_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*gitea*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)

    echo "Gitea server public IP: ${GITEA_PUBLIC_IP}"
    echo "Gitea server private IP: ${GITEA_PRIVATE_IP}"
    
    # Ensure we have a valid IP before proceeding
    if [ -z "$GITEA_PRIVATE_IP" ] || [ "$GITEA_PRIVATE_IP" == "None" ] || [ "$GITEA_PRIVATE_IP" == "null" ]; then
        echo "ERROR: Could not determine Gitea private IP address. Please check if the Gitea instance is running."
        exit 1
    fi
    
    # Setup known_hosts file for Gitea
    echo "Setting up known_hosts for Gitea server at ${GITEA_PRIVATE_IP} (private IP)..."
    
    # Create a known_hosts file
    KNOWN_HOSTS_FILE="$(pwd)/known_hosts"
    WORKFLOW_KNOWN_HOSTS_FILE="${REPO_ROOT}/workflow-scripts/known_hosts"
    
    # Make sure the file exists and is empty
    > "${KNOWN_HOSTS_FILE}"
    
    # Add the Gitea server's SSH key to known_hosts using private IP
    echo "Adding Gitea SSH key to known_hosts..."
    ssh-keyscan -p 222 -H "${GITEA_PRIVATE_IP}" > "${KNOWN_HOSTS_FILE}" 2>/dev/null
    
    # Check if the key was added successfully
    if [ ! -s "${KNOWN_HOSTS_FILE}" ]; then
        echo "Warning: Could not retrieve SSH key from Gitea server. Waiting and trying again..."
        sleep 30
        ssh-keyscan -p 222 -H "${GITEA_PRIVATE_IP}" > "${KNOWN_HOSTS_FILE}" 2>/dev/null
    fi
    
    # Check again and provide feedback
    if [ -s "${KNOWN_HOSTS_FILE}" ]; then
        echo "Successfully added Gitea server to known_hosts:"
        cat "${KNOWN_HOSTS_FILE}"
        
        # Copy the known_hosts file to the workflow-scripts directory
        echo "Copying known_hosts to workflow-scripts directory..."
        cp "${KNOWN_HOSTS_FILE}" "${WORKFLOW_KNOWN_HOSTS_FILE}"
        echo "known_hosts file copied to ${WORKFLOW_KNOWN_HOSTS_FILE}"
    else
        echo "ERROR: Could not add Gitea server to known_hosts. File is empty."
        echo "Manual intervention required. Please run:"
        echo "ssh-keyscan -p 222 -H ${GITEA_PRIVATE_IP} > ${KNOWN_HOSTS_FILE}"
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

# Setup SSH key for Gitea using basic authentication
setup_gitea_ssh() {
    echo "Setting up SSH key for Gitea..."
    
    # Get Gitea information - reusing variables from earlier in the script
    GITEA_URL="http://${GITEA_PRIVATE_IP}:3000"
    GITEA_USER="admin"
    
    echo "Using basic authentication to add SSH key..."
    
    # Use the specific SSH public key from the environment directory
    SSH_PUBLIC_KEY_PATH="$HOME/environment/flux.pub"
    if [ ! -f "$SSH_PUBLIC_KEY_PATH" ]; then
        echo "ERROR: SSH public key not found at $SSH_PUBLIC_KEY_PATH"
        exit 1
    fi

    # Add SSH public key to the admin user using basic authentication
    PUBLIC_KEY=$(cat "$SSH_PUBLIC_KEY_PATH")
    KEY_RESPONSE=$(curl -s -X POST \
      "${GITEA_URL}/api/v1/user/keys" \
      -H "Content-Type: application/json" \
      -u "${GITEA_USER}:${GITEA_PASSWORD}" \
      -d "{\"title\":\"flux-key\", \"key\":\"${PUBLIC_KEY}\"}")

    if [[ "$KEY_RESPONSE" == *"id"* ]]; then
        echo "Successfully added SSH key to Gitea admin user"
    else
        echo "Note: SSH key addition returned: $KEY_RESPONSE"
        echo "Continuing with setup (key may already exist)..."
    fi

    echo "Gitea SSH setup completed successfully!"
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
    echo "Known hosts file created at: ${KNOWN_HOSTS_FILE}"
    echo ""
    echo "Your EKS cluster has been configured."
    echo "=============================="
}

# Main execution
main() {
    check_prerequisites
    deploy_terraform_infra
    setup_gitea_ssh  # Add SSH key to Gitea
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
