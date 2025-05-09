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
    
    # Ensure we have a valid private IP before proceeding
    if [ -z "$GITEA_PRIVATE_IP" ] || [ "$GITEA_PRIVATE_IP" == "None" ] || [ "$GITEA_PRIVATE_IP" == "null" ]; then
        echo "ERROR: Could not determine Gitea private IP address. Please check if the Gitea instance is running."
        exit 1
    fi
    
    # Setup known_hosts file for Gitea
    echo "Setting up known_hosts for Gitea server at ${GITEA_PRIVATE_IP} (private IP)..."
    
    # Create a temporary known_hosts file
    KNOWN_HOSTS_FILE="$(pwd)/known_hosts"
    
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
    else
        echo "ERROR: Could not add Gitea server to known_hosts. File is empty."
        echo "Manual intervention required. Please run:"
        echo "ssh-keyscan -p 222 -H ${GITEA_PRIVATE_IP} > ${KNOWN_HOSTS_FILE}"
        exit 1
    fi
    
    # Create flux-secrets.yaml file using existing keys from CloudFormation
    echo "Creating flux-secrets.yaml file..."
    
    # Check if SSH keys exist
    if [ ! -f ~/.ssh/id_rsa ] || [ ! -f ~/.ssh/id_rsa.pub ]; then
        echo "ERROR: SSH keys not found at ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub"
        exit 1
    fi
    
    # Use existing keys from CloudFormation
    cat > "flux-secrets.yaml" << EOF
secret:
  create: true
  data:
    identity: |-
$(sed 's/^/      /' ~/.ssh/id_rsa)
    identity.pub: |-
$(sed 's/^/      /' ~/.ssh/id_rsa.pub)
    known_hosts: |-
$(sed 's/^/      /' "${KNOWN_HOSTS_FILE}")
EOF

    # Verify the file was created and has content
    if [ ! -s "flux-secrets.yaml" ]; then
        echo "ERROR: flux-secrets.yaml is empty or was not created properly."
        exit 1
    else
        echo "Created flux-secrets.yaml at $(pwd)/flux-secrets.yaml"
        echo "File size: $(wc -l < flux-secrets.yaml) lines"
    fi
        
    # Get the AWS region from Terraform or environment variable
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo ${AWS_REGION:-$(aws configure get region)})
    
    # Configure kubectl to connect to the new cluster
    if [ -n "$AWS_REGION" ]; then
        echo "Configuring kubectl for region: $AWS_REGION"
        aws eks update-kubeconfig --name eks-saas-gitops --region "$AWS_REGION"
    else
        echo "ERROR: Could not determine AWS region. Please set AWS_REGION environment variable."
        exit 1
    fi
}

setup_gitea_ssh() {
        echo "Setting up SSH key for Gitea..."
    
    # Get Gitea information - reusing variables from earlier in the script
    GITEA_URL="http://${GITEA_PRIVATE_IP}:3000"
    GITEA_USER="admin"
    
    # Get existing token from SSM
    GITEA_TOKEN=$(aws ssm get-parameter \
        --name "/eks-saas-gitops/gitea-flux-token" \
        --with-decryption \
        --query 'Parameter.Value' \
        --output text)
    
    if [ -z "$GITEA_TOKEN" ] || [ "$GITEA_TOKEN" == "None" ]; then
        echo "ERROR: Could not retrieve Gitea token from SSM"
        exit 1
    fi
    
    echo "Successfully retrieved Gitea token from SSM"

    # Use the specific SSH public key from the environment directory
    SSH_PUBLIC_KEY_PATH="$HOME/environment/flux.pub"
    if [ ! -f "$SSH_PUBLIC_KEY_PATH" ]; then
        echo "ERROR: SSH public key not found at $SSH_PUBLIC_KEY_PATH"
        exit 1
    fi

    # Add SSH public key to the admin user
    echo "Adding SSH public key to Gitea admin user..."
    PUBLIC_KEY=$(cat "$SSH_PUBLIC_KEY_PATH")
    KEY_RESPONSE=$(curl -s -X POST \
      "${GITEA_URL}/api/v1/user/keys" \
      -H "Content-Type: application/json" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -d "{\"title\":\"flux-key\", \"key\":\"${PUBLIC_KEY}\"}")

    if [[ "$KEY_RESPONSE" == *"id"* ]]; then
        echo "Successfully added SSH key to Gitea admin user"
    else
        echo "Failed to add SSH key. Response: $KEY_RESPONSE"
        exit 1
    fi

    echo "Gitea SSH setup completed successfully!"
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
    setup_gitea_ssh
    print_setup_info
}

# Run the script
main
