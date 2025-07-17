#!/bin/bash

# Create a log file that will be accessible after SSH login
LOG_FILE="/var/log/gitea-setup.log"
touch $LOG_FILE
chmod 644 $LOG_FILE

# Function for logging with timestamps
log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $1" | tee -a $LOG_FILE
}

# Log section headers for better readability
log_section() {
  log "----------------------------------------"
  log "# $1"
  log "----------------------------------------"
}

# Redirect all output to both console and log file
exec > >(tee -a $LOG_FILE) 2>&1

log_section "STARTING GITEA SETUP"

# Update and install dependencies
log_section "INSTALLING DEPENDENCIES"
# Install required packages
yum update -y -q
yum install -y -q libxcrypt-compat docker git
systemctl start docker
systemctl enable docker
sudo usermod -aG docker ec2-user

# Set up git configuration
export HOME=/root
git config --global init.defaultBranch main

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
log "Dependencies installed successfully"

# Basic configuration
log_section "CONFIGURING GITEA"
# Get AWS region and private IP from metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
log "AWS Region: $AWS_REGION"
log "Private IP: $PRIVATE_IP"

# Set Gitea configuration
GITEA_PORT=3000
GITEA_SSH_PORT=222
GITEA_ADMIN_USER="admin"

# Get admin password from SSM
GITEA_ADMIN_PASSWORD=$(aws ssm get-parameter --name "/eks-saas-gitops/gitea-admin-password" --with-decryption --query 'Parameter.Value' --output text --region $AWS_REGION)
if [ -z "$GITEA_ADMIN_PASSWORD" ]; then
    log "ERROR: Failed to retrieve admin password from SSM"
    exit 1
fi

# Create directory structure
INSTALL_DIR="$(pwd)/gitea-install"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Setting up random 32 caracteres token for Gitea Actions
RUNNER_TOKEN=$(openssl rand -hex 16)

# Create docker-compose.yml with Actions enabled
log "Creating Gitea docker-compose configuration..."
cat > docker-compose.yml << EOF
version: "3"
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__security__INSTALL_LOCK=true
      - GITEA__server__ROOT_URL=http://0.0.0.0:${GITEA_PORT}/
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__service__DISABLE_REGISTRATION=true
      - GITEA__service__REQUIRE_SIGNIN_VIEW=false
      # Enable Gitea Actions
      - GITEA__actions__ENABLED=true
      # For Gitea 1.21.0+, only "github" or "self" are allowed values
      - GITEA__actions__DEFAULT_ACTIONS_URL=github
      - GITEA_RUNNER_REGISTRATION_TOKEN=${RUNNER_TOKEN}
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    network_mode: "host"
    restart: always
EOF
log "Docker Compose configuration created"

# Start Gitea
log_section "STARTING GITEA"
# Stop any existing containers and start Gitea
docker-compose down -v
docker-compose up -d
log "Gitea container started"

# Wait for Gitea to initialize
log "Waiting for Gitea to initialize..."
until curl -s http://localhost:${GITEA_PORT}/api/v1/version > /dev/null; do
    sleep 5
done

# Create admin user
log "Creating admin user..."
docker exec -u git gitea gitea admin user create \
    --username ${GITEA_ADMIN_USER} \
    --password ${GITEA_ADMIN_PASSWORD} \
    --email admin@example.com \
    --admin \
    --must-change-password=false

# Generate token for Flux and store in SSM
log_section "GENERATING FLUX TOKEN"
sleep 5  # Wait for admin user to be fully created

# Create a token for Flux
FLUX_TOKEN_NAME="flux-token"
log "Creating Flux API token..."
FLUX_TOKEN_RESPONSE=$(curl -s -X POST \
  "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  -H "Content-Type: application/json" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  -d "{\"name\":\"${FLUX_TOKEN_NAME}\", \"scopes\": [\"write:repository\", \"write:user\", \"write:organization\"]}")

# Extract the token from the response
FLUX_TOKEN=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

# Handle token creation failure
if [ -z "$FLUX_TOKEN" ]; then
    ERROR_MSG=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    log "Failed to generate Flux token: $ERROR_MSG"
    
    # If token already exists, create a new one with a timestamp
    if [[ "$ERROR_MSG" == *"already exists"* ]]; then
        NEW_TOKEN_NAME="${FLUX_TOKEN_NAME}-$(date +%s)"
        log "Creating new token with name: $NEW_TOKEN_NAME"
        
        FLUX_TOKEN_RESPONSE=$(curl -s -X POST \
          "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
          -H "Content-Type: application/json" \
          -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
          -d "{\"name\":\"${NEW_TOKEN_NAME}\", \"scopes\": [\"write:repository\", \"write:user\", \"write:organization\"]}")
        
        FLUX_TOKEN=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)
    fi
fi

# Store token in SSM if successful
if [ -n "$FLUX_TOKEN" ]; then
    log "Storing Flux token in SSM Parameter Store..."
    aws ssm put-parameter \
        --name "/eks-saas-gitops/gitea-flux-token" \
        --type "SecureString" \
        --value "$FLUX_TOKEN" \
        --region "$AWS_REGION" \
        --overwrite
else
    log "ERROR: Failed to generate Flux token"
fi

# Set up Gitea Actions Runner
log_section "SETTING UP GITEA ACTIONS RUNNER"

# Wait for Gitea API to be ready
sleep 10

if [ -n "$RUNNER_TOKEN" ]; then
    log "Starting Gitea runner container..."
    
    # Stop any existing runner container
    docker stop gitea_runner 2>/dev/null || true
    docker rm gitea_runner 2>/dev/null || true
    
    # Run the runner container with environment variables and host network
    docker run -d \
      --name gitea_runner \
      --restart always \
      --network host \
      -e GITEA_INSTANCE_URL=http://${PRIVATE_IP}:${GITEA_PORT} \
      -e GITEA_RUNNER_REGISTRATION_TOKEN=${RUNNER_TOKEN} \
      -v /var/run/docker.sock:/var/run/docker.sock \
      gitea/act_runner:latest
    
    log "Gitea runner container started"
else
    log "ERROR: Failed to get runner token, cannot start runner container"
fi

# Create a token for CI/CD operations
log_section "CREATING CI/CD TOKEN"
CICD_TOKEN_NAME="cicd-token"
log "Creating CI/CD API token..."
CICD_TOKEN_RESPONSE=$(curl -s -X POST \
  "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  -H "Content-Type: application/json" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  -d "{\"name\":\"${CICD_TOKEN_NAME}\", \"scopes\": [\"write:repository\", \"write:package\", \"write:organization\", \"write:user\", \"write:issue\", \"write:notification\", \"read:notification\", \"write:admin\"]}")

# Extract the token from the response
CICD_TOKEN=$(echo $CICD_TOKEN_RESPONSE | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

# Store token in SSM if successful
if [ -n "$CICD_TOKEN" ]; then
    log "Storing CI/CD token in SSM Parameter Store..."
    aws ssm put-parameter \
        --name "/eks-saas-gitops/gitea-cicd-token" \
        --type "SecureString" \
        --value "$CICD_TOKEN" \
        --region "$AWS_REGION" \
        --overwrite
else
    log "ERROR: Failed to generate CI/CD token"
fi

log_section "SETUP COMPLETE"
log "Gitea and Gitea Actions Runner setup completed successfully"
log "Log file is available at: $LOG_FILE"
