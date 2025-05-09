#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update and install dependencies
yum update -y -q
yum install -y -q libxcrypt-compat
yum install -y -q docker
yum install -y -q git
systemctl start docker
systemctl enable docker
sudo usermod -aG docker ec2-user

export HOME=/root
git config --global init.defaultBranch main

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Basic configuration
GITEA_PORT=3000
GITEA_SSH_PORT=222
GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASSWORD=$(aws ssm get-parameter --name "/eks-saas-gitops/gitea-admin-password" --with-decryption --query 'Parameter.Value' --output text)
if [ -z "$GITEA_ADMIN_PASSWORD" ]; then
    echo "Failed to retrieve admin password from SSM"
    exit 1
fi
INSTALL_DIR="$(pwd)/gitea-install"

# Create directory structure
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create docker-compose.yml
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
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
    network_mode: "bridge"
    restart: always
EOF

# Start Gitea
docker-compose down -v
docker-compose up -d

echo "Waiting for Gitea to initialize..."
until curl -s http://localhost:${GITEA_PORT}/api/v1/version > /dev/null; do
    sleep 1
done

echo "Creating admin user..."
docker exec -u git gitea gitea admin user create \
    --username ${GITEA_ADMIN_USER} \
    --password ${GITEA_ADMIN_PASSWORD} \
    --email admin@example.com \
    --admin \
    --must-change-password=false

# Generate token for Flux and store in SSM
echo "Generating Flux API token..."
sleep 5  # Give some time for the admin user to be fully created

# Create a token for Flux
FLUX_TOKEN_NAME="flux-token"
FLUX_TOKEN_RESPONSE=$(curl -s -X POST \
  "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  -H "Content-Type: application/json" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  -d "{\"name\":\"${FLUX_TOKEN_NAME}\", \"scopes\": [\"write:admin\"]}")

# Extract the token from the response
FLUX_TOKEN=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)

if [ -z "$FLUX_TOKEN" ]; then
    echo "Failed to generate Flux token"
    # Try to extract error message
    ERROR_MSG=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    echo "Error: $ERROR_MSG"
    
    # If token already exists, try to get it
    if [[ "$ERROR_MSG" == *"already exists"* ]]; then
        echo "Token already exists, trying to get existing tokens..."
        TOKENS_RESPONSE=$(curl -s -X GET \
          "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
          -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}")
        
        echo "Available tokens: $TOKENS_RESPONSE"
        # Note: We can't retrieve the actual token value of existing tokens via API
        # Will need to create a new token with a different name
        NEW_TOKEN_NAME="${FLUX_TOKEN_NAME}-$(date +%s)"
        echo "Creating new token with name: $NEW_TOKEN_NAME"
        
        FLUX_TOKEN_RESPONSE=$(curl -s -X POST \
          "http://localhost:${GITEA_PORT}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
          -H "Content-Type: application/json" \
          -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
          -d "{\"name\":\"${NEW_TOKEN_NAME}\", \"scopes\": [\"write:admin\"]}")
        
        FLUX_TOKEN=$(echo $FLUX_TOKEN_RESPONSE | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)
    fi
fi

if [ -n "$FLUX_TOKEN" ]; then
    echo "Flux token generated successfully"
    # Store the token in SSM Parameter Store
    aws ssm put-parameter \
        --name "/eks-saas-gitops/gitea-flux-token" \
        --type "SecureString" \
        --value "$FLUX_TOKEN" \
        --overwrite
    
    echo "Flux token stored in SSM Parameter Store at /eks-saas-gitops/gitea-flux-token"
else
    echo "Failed to generate Flux token after retry"
fi

echo "Gitea setup complete"


