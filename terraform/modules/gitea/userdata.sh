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

# Create working directory
WORK_DIR="/tmp/gitea-work"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# Clone source repository from your GitHub
echo "Cloning source repository from GitHub..."
git clone https://github.com/ande28em/eks-saas-gitops.git "${WORK_DIR}/source"

# First, create a repository for the entire project to verify cloning works
echo "Creating repository: eks-saas-gitops"
curl -X POST "http://localhost:${GITEA_PORT}/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    -d "{\"name\":\"eks-saas-gitops\",\"description\":\"Complete GitHub source repository\"}" > /dev/null

sleep 5

# Push the entire cloned repository to Gitea
cd "${WORK_DIR}/source"
git remote add gitea "http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}@localhost:${GITEA_PORT}/${GITEA_ADMIN_USER}/eks-saas-gitops.git"
git push -u gitea main

# Check if tenant-microservices directory exists
echo "Checking tenant-microservices directory..."
if [ ! -d "${WORK_DIR}/source/tenant-microservices" ]; then
    echo "Error: tenant-microservices directory not found in the cloned repository!"
    ls -la "${WORK_DIR}/source"
else
    echo "Found tenant-microservices directory. Contents:"
    ls -la "${WORK_DIR}/source/tenant-microservices"
    
    # Create and push individual repositories
    for repo in "consumer" "producer" "payments"; do
        echo "Creating repository: $repo"
        
        # Create repository
        curl -X POST "http://localhost:${GITEA_PORT}/api/v1/user/repos" \
            -H "Content-Type: application/json" \
            -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
            -d "{\"name\":\"${repo}\",\"description\":\"${repo} repository\"}" > /dev/null
        
        sleep 5
        
        # Check if the microservice directory exists
        if [ -d "${WORK_DIR}/source/tenant-microservices/${repo}" ]; then
            echo "Found ${repo} directory. Contents:"
            ls -la "${WORK_DIR}/source/tenant-microservices/${repo}"
            
            # Create temp directory for this repo
            mkdir -p "${WORK_DIR}/${repo}"
            cp -r "${WORK_DIR}/source/tenant-microservices/${repo}/"* "${WORK_DIR}/${repo}/" || echo "Warning: Copy failed for ${repo}"
            
            # Initialize and push
            cd "${WORK_DIR}/${repo}"
            git init
            git add .
            git config user.email "admin@example.com"
            git config user.name "${GITEA_ADMIN_USER}"
            git commit -m "Initial commit"
            git remote add origin "http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}@localhost:${GITEA_PORT}/${GITEA_ADMIN_USER}/${repo}.git"
            git push -u origin main
        else
            echo "Warning: ${repo} directory not found in tenant-microservices!"
        fi
        
        cd "${INSTALL_DIR}"
    done
fi

# Also create a repository for the main project
echo "Creating repository: eks-saas-gitops"
curl -X POST "http://localhost:${GITEA_PORT}/api/v1/user/repos" \
    -H "Content-Type: application/json" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    -d "{\"name\":\"eks-saas-gitops\",\"description\":\"Main EKS SaaS GitOps repository\"}" > /dev/null

sleep 5

# Copy the main repository content
mkdir -p "${WORK_DIR}/eks-saas-gitops"
cp -r "${WORK_DIR}/source"/* "${WORK_DIR}/eks-saas-gitops/"
cp -r "${WORK_DIR}/source/.gitignore" "${WORK_DIR}/eks-saas-gitops/" 2>/dev/null || true

# Remove unnecessary folders before pushing
rm -rf "${WORK_DIR}/eks-saas-gitops/helpers" 2>/dev/null || true
rm -rf "${WORK_DIR}/eks-saas-gitops/tenant-microservices" 2>/dev/null || true

# Initialize and push the main repository
cd "${WORK_DIR}/eks-saas-gitops"
git init
git add .
git config user.email "admin@example.com"
git config user.name "${GITEA_ADMIN_USER}"
git commit -m "Initial commit"
git remote add origin "http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}@localhost:${GITEA_PORT}/${GITEA_ADMIN_USER}/eks-saas-gitops.git"
git push -u origin main
git tag v0.0.1 HEAD
git push origin v0.0.1
cd "${INSTALL_DIR}"

# Cleanup
rm -rf "${WORK_DIR}"

# List repositories
echo "Listing created repositories:"
curl -s -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    "http://localhost:${GITEA_PORT}/api/v1/user/repos" | grep -o '"name":"[^"]*"' | cut -d'"' -f4

echo "Gitea setup complete"

# TODO Generate token for Flux and store in SSM

