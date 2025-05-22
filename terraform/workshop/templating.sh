#!/bin/bash
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELM_CHARTS_DIR="${REPO_ROOT}/helm-charts"
MICROSERVICES_DIR="${REPO_ROOT}/tenant-microservices"

# Get AWS account ID and region from terraform outputs
AWS_ACCOUNT_ID=$(terraform output -raw account_id)
AWS_REGION=$(terraform output -raw aws_region)

# Get Gitea information
GITEA_PRIVATE_IP=$(terraform output -raw gitea_private_ip)
GITEA_PORT="3000"
GITEA_ADMIN_USER="admin"
GITEA_TOKEN=$(aws ssm get-parameter --name "/eks-saas-gitops/gitea-flux-token" --with-decryption --query 'Parameter.Value' --output text)

# Get ECR repository URLs from terraform outputs
PRODUCER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.producer')
CONSUMER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.consumer')
PAYMENTS_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.payments')
ECR_HELM_CHART_URL=$(terraform output -raw ecr_helm_chart_url_base)
ECR_ARGOWORKFLOW_CONTAINER=$(terraform output -raw ecr_argoworkflow_container)

echo "Creating values.yaml from template..."

# Create values.yaml file from template with substitutions
cat "${HELM_CHARTS_DIR}/helm-tenant-chart/values.yaml.template" | \
  sed "s|{account_id}|${AWS_ACCOUNT_ID}|g" | \
  sed "s|{ecr_repository_urls_producer}|${PRODUCER_ECR_URL}|g" | \
  sed "s|{ecr_repository_urls_consumer}|${CONSUMER_ECR_URL}|g" \
  > "${HELM_CHARTS_DIR}/helm-tenant-chart/values.yaml"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Package and push Helm charts to ECR
echo "Packaging and pushing Helm charts to ECR..."
cd "${HELM_CHARTS_DIR}"

# Login to Helm registry
aws ecr get-login-password --region ${AWS_REGION} | helm registry login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Package and push tenant chart
echo "Packaging and pushing tenant chart..."
helm package helm-tenant-chart
TENANT_CHART_PACKAGE=$(ls helm-tenant-chart-*.tgz)
helm push ${TENANT_CHART_PACKAGE} oci://${ECR_HELM_CHART_URL}

# Package and push application chart
echo "Packaging and pushing application chart..."
helm package application-chart
APPLICATION_CHART_PACKAGE=$(ls application-chart-*.tgz)
helm push ${APPLICATION_CHART_PACKAGE} oci://${ECR_HELM_CHART_URL}

# Build and push Docker images with tag 0.1
echo "Building and pushing Docker images to ECR..."

# Build and push producer image
echo "Building producer image..."
cd "${MICROSERVICES_DIR}/producer"
sudo docker build -t ${PRODUCER_ECR_URL}:0.1 .
sudo docker push ${PRODUCER_ECR_URL}:0.1

# Build and push consumer image
echo "Building consumer image..."
cd "${MICROSERVICES_DIR}/consumer"
sudo docker build -t ${CONSUMER_ECR_URL}:0.1 .
sudo docker push ${CONSUMER_ECR_URL}:0.1

# Build and push payments image
echo "Building payments image..."
cd "${MICROSERVICES_DIR}/payments"
sudo docker build -t ${PAYMENTS_ECR_URL}:0.1 .
sudo docker push ${PAYMENTS_ECR_URL}:0.1

# Build and push workflow container image
echo "Building and pushing workflow container image..."
WORKFLOW_SCRIPTS_DIR="${REPO_ROOT}/workflow-scripts"

echo "Current directory before cd: $(pwd)"
cd "${WORKFLOW_SCRIPTS_DIR}"

# Build and push argo_workflows image
sudo docker build -t ${ECR_ARGOWORKFLOW_CONTAINER}:0.1 .
sudo docker push ${ECR_ARGOWORKFLOW_CONTAINER}:0.1

# Create tag v0.0.1 for the eks-saas-gitops repository
echo "Creating tag v0.0.1 for the eks-saas-gitops repository..."
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Clone the repository
git clone "http://${GITEA_ADMIN_USER}:${GITEA_TOKEN}@${GITEA_PRIVATE_IP}:${GITEA_PORT}/${GITEA_ADMIN_USER}/eks-saas-gitops.git"
cd eks-saas-gitops

# Create and push the tag
git tag -a v0.0.1 -m "Initial version"
git push origin v0.0.1

# Clean up
cd "${REPO_ROOT}"
rm -rf "${TEMP_DIR}"

echo "Templating, image pushing, and tag creation completed successfully!"