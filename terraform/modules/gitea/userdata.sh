#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update and install dependencies
yum update -y -q
yum install -y -q libxcrypt-compat
yum install -y -q docker
systemctl start docker
systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Basic configuration
GITEA_PORT="${GITEA_PORT}"
GITEA_SSH_PORT="${GITEA_SSH_PORT}"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD}"
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
      - GITEA__server__ROOT_URL=http://localhost:${GITEA_PORT}/
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
docker exec -u 1000 gitea gitea admin user create --username ${GITEA_ADMIN_USER} --password ${GITEA_ADMIN_PASSWORD} --email admin@example.com --admin

# Create working directory
WORK_DIR="/tmp/gitea-work"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# Clone source repository
git clone https://github.com/aws-samples/eks-saas-gitops.git "${WORK_DIR}/source"

# Create and push repositories
for repo in "consumer" "producer" "payments"; do
    echo "Creating repository: $repo"
    
    # Create repository
    curl -X POST "http://localhost:${GITEA_PORT}/api/v1/user/repos" \
        -H "Content-Type: application/json" \
        -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
        -d "{\"name\":\"${repo}\",\"description\":\"${repo} repository\"}" > /dev/null
    
    sleep 5
    
    # Create temp directory for this repo
    mkdir -p "${WORK_DIR}/${repo}"
    cp -r "${WORK_DIR}/source/tenant-microservices/${repo}"/* "${WORK_DIR}/${repo}/"
    
    # Initialize and push
    cd "${WORK_DIR}/${repo}"
    git init
    git add .
    git config user.email "admin@example.com"
    git config user.name "${GITEA_ADMIN_USER}"
    git commit -m "Initial commit"
    git remote add origin "http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}@localhost:${GITEA_PORT}/${GITEA_ADMIN_USER}/${repo}.git"
    git push -u origin main
    cd "${INSTALL_DIR}"
done

# Cleanup
rm -rf "${WORK_DIR}"

# List repositories
echo "Listing created repositories:"
curl -s -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    "http://localhost:${GITEA_PORT}/api/v1/user/repos" | grep -o '"name":"[^"]*"' | cut -d'"' -f4

echo "Gitea setup complete"