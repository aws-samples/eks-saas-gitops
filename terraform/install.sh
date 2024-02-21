#!/bin/bash

# Set the base directory to the parent directory of this script
BASE_DIR=$(dirname "$0")

# Ask for public and private key file paths
echo "Enter the public key file path:"
read -r public_key_file_path

echo "Enter the private key file path:"
read -r private_key_file_path

# Navigate to the workshop directory where the module implementations are
cd "$BASE_DIR/workshop" || exit

# Initialize Terraform
terraform init
terraform validate

# Define the list of modules and resources to apply in order
declare -a terraform_targets=(
    "module.vpc"
    "module.ebs_csi_irsa_role"
    "module.eks"
    "module.gitops_saas_infra"
    "null_resource.execute_templating_script"
    "module.flux_v2"
)

# Apply the Terraform configurations in the specified order
for target in "${terraform_targets[@]}"; do
    echo "Applying: $target"
    terraform apply -target="$target" \
        -var "public_key_file_path=$public_key_file_path" \
        -var "private_key_file_path=$private_key_file_path" \
        -auto-approve
done

echo "All specified Terraform modules and resources have been applied."