#!/bin/bash
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MICROSERVICES_DIR="${REPO_ROOT}/tenant-microservices"
REPO_DIR="${SCRIPT_DIR}/temp-repos"

# Check if required tools are installed
command -v git >/dev/null 2>&1 || { echo "Error: git is required but not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is required but not installed."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is required but not installed."; exit 1; }

echo "Getting configuration from Terraform outputs..."

# Get AWS account ID and region from terraform outputs
AWS_ACCOUNT_ID=$(terraform output -raw account_id)
AWS_REGION=$(terraform output -raw aws_region)

# Get Gitea information
GITEA_PRIVATE_IP=$(terraform output -raw gitea_private_ip)
GITEA_PORT="3000"
GITEA_URL="http://${GITEA_PRIVATE_IP}:${GITEA_PORT}"
GITEA_ADMIN_USER="admin"

# Get Gitea token from SSM Parameter Store
echo "Getting Gitea token from SSM Parameter Store..."
GITEA_TOKEN=$(aws ssm get-parameter --name "/eks-saas-gitops/gitea-flux-token" --with-decryption --query 'Parameter.Value' --output text)

if [[ -z "$GITEA_TOKEN" ]]; then
  echo "Error: Failed to get Gitea token from SSM Parameter Store"
  exit 1
fi

# Get ECR repository URLs from terraform outputs
echo "Getting ECR repository URLs from Terraform outputs..."
PRODUCER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.producer')
CONSUMER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.consumer')
PAYMENTS_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.payments')

# Define microservices and their ECR URLs
declare -A MICROSERVICES_ECR
MICROSERVICES_ECR["producer"]="${PRODUCER_ECR_URL}"
MICROSERVICES_ECR["consumer"]="${CONSUMER_ECR_URL}"
MICROSERVICES_ECR["payments"]="${PAYMENTS_ECR_URL}"

# Create temporary directory for repositories
mkdir -p "$REPO_DIR"

# Process each microservice
for SERVICE in "${!MICROSERVICES_ECR[@]}"; do
  echo "Processing $SERVICE..."
  
  # Create repository
  echo "Creating repository for $SERVICE..."
  REPO_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d "{\"name\":\"$SERVICE\", \"description\":\"$SERVICE microservice\", \"private\":false, \"auto_init\":false}")
  
  REPO_NAME=$(echo $REPO_RESPONSE | jq -r '.name // empty')
  if [[ -z "$REPO_NAME" ]]; then
    # Check if repository already exists
    REPO_CHECK=$(curl -s -X GET \
      "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${SERVICE}" \
      -H "Authorization: token $GITEA_TOKEN")
    
    EXISTING_REPO_NAME=$(echo $REPO_CHECK | jq -r '.name // empty')
    if [[ -z "$EXISTING_REPO_NAME" ]]; then
      echo "Error: Failed to create repository for $SERVICE"
      echo "Response: $REPO_RESPONSE"
      continue
    else
      echo "Repository $SERVICE already exists, continuing with setup..."
    fi
  fi
  
  # Get ECR URL for this service
  ECR_URL="${MICROSERVICES_ECR[$SERVICE]}"
  if [[ -z "$ECR_URL" || "$ECR_URL" == "null" ]]; then
    echo "Error: Failed to get ECR URL for $SERVICE"
    continue
  fi
  echo "ECR URL for $SERVICE: $ECR_URL"
  
  # Clone the microservice code
  echo "Preparing $SERVICE code..."
  SERVICE_DIR="$REPO_DIR/$SERVICE"
  mkdir -p "$SERVICE_DIR"
  
  # Copy the microservice files from the tenant-microservices directory
  cp -r "${MICROSERVICES_DIR}/${SERVICE}/"* "$SERVICE_DIR/"
  
  # Ensure the .gitea/workflows directory exists and copy workflow files if they exist
  if [[ -d "${MICROSERVICES_DIR}/${SERVICE}/.gitea/workflows" ]]; then
    mkdir -p "$SERVICE_DIR/.gitea/workflows"
    cp -r "${MICROSERVICES_DIR}/${SERVICE}/.gitea/workflows/"* "$SERVICE_DIR/.gitea/workflows/"
  fi
  
  # Initialize git repository and push
  cd "$SERVICE_DIR"
  git init
  git checkout -b main
  git add .
  git config --local user.email "admin@example.com"
  git config --local user.name "Admin"
  git commit -m "Initial commit"

  # Add remote with embedded credentials
  git remote add origin "http://${GITEA_ADMIN_USER}:${GITEA_TOKEN}@${GITEA_PRIVATE_IP}:${GITEA_PORT}/${GITEA_ADMIN_USER}/${SERVICE}.git"

  # Push to Gitea
  echo "Pushing $SERVICE code to Gitea..."
  git push origin main
  
  # Set repository variables
  echo "Setting repository variables for $SERVICE..."
  
  # Set AWS_REGION variable
  echo "Setting AWS_REGION variable..."
  REGION_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${SERVICE}/actions/variables/AWS_REGION" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d "{\"value\":\"${AWS_REGION}\"}")
  
  # Check if variable already exists and update if needed
  if [[ $(echo $REGION_RESPONSE | jq -r '.message // empty') == *"already exists"* ]]; then
    echo "AWS_REGION variable already exists, updating..."
    REGION_RESPONSE=$(curl -s -X PATCH \
      "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${SERVICE}/actions/variables/AWS_REGION" \
      -H "Content-Type: application/json" \
      -H "Authorization: token $GITEA_TOKEN" \
      -d "{\"value\":\"${AWS_REGION}\"}")
  fi
  
  echo "AWS_REGION response: $REGION_RESPONSE"
  
  # Set REPOSITORY_URI variable
  echo "Setting REPOSITORY_URI variable..."
  REPO_URI_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${SERVICE}/actions/variables/REPOSITORY_URI" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d "{\"value\":\"${ECR_URL}\"}")
  
  # Check if variable already exists and update if needed
  if [[ $(echo $REPO_URI_RESPONSE | jq -r '.message // empty') == *"already exists"* ]]; then
    echo "REPOSITORY_URI variable already exists, updating..."
    REPO_URI_RESPONSE=$(curl -s -X PATCH \
      "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${SERVICE}/actions/variables/REPOSITORY_URI" \
      -H "Content-Type: application/json" \
      -H "Authorization: token $GITEA_TOKEN" \
      -d "{\"value\":\"${ECR_URL}\"}")
  fi
  
  echo "REPOSITORY_URI response: $REPO_URI_RESPONSE"
  
  echo "$SERVICE setup complete"
  cd - > /dev/null
done

echo "All repositories have been set up successfully"
echo "You can now access them at ${GITEA_URL}/admin"

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$REPO_DIR"

echo "Setup complete!"
