#!/bin/bash
set -e

# Check if required tools are installed
command -v git >/dev/null 2>&1 || { echo "Error: git is required but not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is required but not installed."; exit 1; }

# Configuration
GITEA_URL=""
GITEA_USER="admin"
GITEA_PASSWORD=""
AWS_REGION=""
MICROSERVICES=("producer" "consumer" "payments")
REPO_DIR="$(pwd)/temp-repos"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --gitea-url)
      GITEA_URL="$2"
      shift 2
      ;;
    --gitea-password)
      GITEA_PASSWORD="$2"
      shift 2
      ;;
    --aws-region)
      AWS_REGION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$GITEA_URL" ]]; then
  echo "Error: --gitea-url is required"
  exit 1
fi

if [[ -z "$GITEA_PASSWORD" ]]; then
  echo "Error: --gitea-password is required"
  exit 1
fi

if [[ -z "$AWS_REGION" ]]; then
  echo "Error: --aws-region is required"
  exit 1
fi

# Remove trailing slash from URL if present
GITEA_URL=${GITEA_URL%/}

# Create a token for API access
echo "Creating API token..."
TOKEN_RESPONSE=$(curl -s -X POST \
  "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" \
  -H "Content-Type: application/json" \
  -u "${GITEA_USER}:${GITEA_PASSWORD}" \
  -d "{\"name\":\"setup-token-$(date +%s)\", \"scopes\": [\"write:repository\", \"write:user\", \"write:organization\"]}")

TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.sha1 // empty')

if [[ -z "$TOKEN" ]]; then
  echo "Error: Failed to create API token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "API token created successfully"

# Get ECR repository URLs from Terraform output
echo "Getting ECR repository URLs..."
ECR_URLS=$(terraform output -json ecr_repository_urls)
if [[ -z "$ECR_URLS" ]]; then
  echo "Error: Failed to get ECR repository URLs from Terraform output"
  exit 1
fi

# Create temporary directory for repositories
mkdir -p "$REPO_DIR"

# Process each microservice
for SERVICE in "${MICROSERVICES[@]}"; do
  echo "Processing $SERVICE..."
  
  # Create repository
  echo "Creating repository for $SERVICE..."
  REPO_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $TOKEN" \
    -d "{\"name\":\"$SERVICE\", \"description\":\"$SERVICE microservice\", \"private\":false, \"auto_init\":false}")
  
  REPO_NAME=$(echo $REPO_RESPONSE | jq -r '.name // empty')
  if [[ -z "$REPO_NAME" ]]; then
    echo "Error: Failed to create repository for $SERVICE"
    echo "Response: $REPO_RESPONSE"
    continue
  fi
  
  # Get ECR URL for this service
  ECR_URL=$(echo $ECR_URLS | jq -r ".[\"$SERVICE\"]")
  if [[ -z "$ECR_URL" || "$ECR_URL" == "null" ]]; then
    echo "Error: Failed to get ECR URL for $SERVICE"
    continue
  fi
  echo $ECR_URL
  
  # Clone the microservice code
  echo "Cloning $SERVICE code..."
  SERVICE_DIR="$REPO_DIR/$SERVICE"
  mkdir -p "$SERVICE_DIR"
  
  # Copy the microservice files from the tenant-microservices directory
  cp -r "../../tenant-microservices/$SERVICE/"* "$SERVICE_DIR/"
  
  # Ensure the .gitea/workflows directory exists
  mkdir -p "$SERVICE_DIR/.gitea/workflows"
  
  # Copy the workflow file
  cp "../../tenant-microservices/$SERVICE/.gitea/workflows/build-and-push.yml" "$SERVICE_DIR/.gitea/workflows/"
  
  # Initialize git repository and push
  cd "$SERVICE_DIR"
  git init
  git add .
  git config --local user.email "admin@example.com"
  git config --local user.name "Admin"
  git commit -m "Initial commit"

  # Extract the hostname part from the URL (remove http:// or https://)
  GITEA_HOST=${GITEA_URL#http*://}

  # Add remote with embedded credentials
  git remote add origin "http://${GITEA_USER}:${TOKEN}@${GITEA_HOST}/${GITEA_USER}/${SERVICE}.git"

  # Push to Gitea (now with credentials in the URL)
  echo "Pushing $SERVICE code to Gitea..."
  git push -u origin main --no-verify
  
  # Set repository variables
  echo "Setting repository variables for $SERVICE..."
  
  # Set AWS_REGION variable
  echo "Setting AWS_REGION variable..."
  REGION_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${SERVICE}/actions/variables/AWS_REGION" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $TOKEN" \
    -d "{\"value\":\"${AWS_REGION}\"}")
  
  echo "AWS_REGION response: $REGION_RESPONSE"
  
  # Set REPOSITORY_URI variable
  echo "Setting REPOSITORY_URI variable..."
  REPO_URI_RESPONSE=$(curl -s -X POST \
    "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${SERVICE}/actions/variables/REPOSITORY_URI" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $TOKEN" \
    -d "{\"value\":\"${ECR_URL}\"}")
  
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
