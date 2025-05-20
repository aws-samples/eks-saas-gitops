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

# Get ECR repository URLs from terraform outputs
PRODUCER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.producer')
CONSUMER_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.consumer')
PAYMENTS_ECR_URL=$(terraform output -json ecr_repositories | jq -r '.payments')
ECR_HELM_CHART_URL=$(terraform output -raw ecr_helm_chart_url_base)

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

# Package tenant chart
aws ecr get-login-password --region ${AWS_REGION} | helm registry login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
helm package helm-tenant-chart
TENANT_CHART_PACKAGE=$(ls helm-tenant-chart-*.tgz)
helm push ${TENANT_CHART_PACKAGE} oci://${ECR_HELM_CHART_URL}

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

echo "Templating and image pushing completed successfully!"