#!/bin/bash
set -e

echo "Starting infrastructure destruction..."

# First, ensure the Gitea token is available in Terraform state
echo "Retrieving Gitea token into Terraform state..."
terraform apply --target data.aws_ssm_parameter.gitea_token --auto-approve

# Run terraform destroy
echo "Running terraform destroy..."
terraform destroy --auto-approve

echo "Infrastructure destruction completed."
