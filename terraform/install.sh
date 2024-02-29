#!/bin/bash

# Set the base directory to the parent directory of this script
BASE_DIR=$(dirname "$0")

# Ask for public and private key file paths
public_key_file_path=$1
private_key_file_path=$2
clone_directory=$3
known_hosts=$4

# Path where values.yaml will be created
values_yaml_path="$BASE_DIR/workshop/values.yaml"

# Create values.yaml with the provided information
cat <<EOF > "$values_yaml_path"
secret:
  create: true
  data:
    identity: |-
$(sed 's/^/      /' $private_key_file_path)
    identity.pub: |-
$(sed 's/^/      /' $public_key_file_path)
    known_hosts: |-
$(sed 's/^/      /' $known_hosts)
EOF

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
    
    # Attempt counter
    attempt=1
    while [ $attempt -le 3 ]; do
        echo "Attempt $attempt of applying $target..."
        
        # Run Terraform apply
        terraform apply -target="$target" \
            -var "public_key_file_path=$public_key_file_path" \
            -var "private_key_file_path=$private_key_file_path" \
            -var "clone_directory=$clone_directory" \
            -var "known_hosts=$known_hosts" \
            -var "flux2_sync_secret_values=$values_yaml_path" \
            -auto-approve
        
        # Check if Terraform apply was successful
        if [ $? -eq 0 ]; then
            echo "$target applied successfully."
            break # Exit the loop if apply was successful
        else
            echo "Failed to apply $target, retrying..."
            ((attempt++)) # Increment attempt counter
            
            # Optional: Add a sleep here if you want to wait before retrying
            # sleep 10
        fi
        
        # If reached maximum attempts and still failed
        if [ $attempt -gt 3 ]; then
            echo "Failed to apply $target after 3 attempts."
            exit 1 # Exit script with error
        fi
    done
done

echo "All specified Terraform modules and resources have been applied."
