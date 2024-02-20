#!/bin/bash

export_simple_outputs() {
    terraform output -json > "$1"

    # Use a temporary file to hold the jq output
    local temp_file=$(mktemp)
    jq -r 'to_entries[] | select(.value.type == "string") | "\(.key)=\(.value.value)"' "$1" > "$temp_file"

    # Read from the temporary file to export variables
    while IFS= read -r line; do
        eval "export $line"
    done < "$temp_file"

    # Clean up the temporary file
    rm "$temp_file"
}


clone_git_repos() {
    local git_urls="$1"  # List of Git repository URLs separated by spaces
    local clone_dir="$2"  # Directory where to clone the repositories

    # Ensure the clone directory exists
    mkdir -p "$clone_dir"

    # Iterate through each Git URL and clone it
    IFS=' ' read -ra urls <<< "$git_urls"
    for url in "${urls[@]}"; do
        # Extract the repository name from the URL
        repo_name=$(basename -s .git "$url")
        target_path="$clone_dir/$repo_name"

        echo "Cloning repository: $url into $target_path"

        # Clone only if the target directory doesn't exist or is empty
        if [ ! -d "$target_path" ] || [ -z "$(ls -A "$target_path")" ]; then
            git clone "$url" "$target_path"
        else
            echo "Skipping clone of '$url'. Target path '$target_path' already exists and is not empty."
        fi
    done
}

# Debug function to test template processing
debug_process_templates() {
    local dir="$1"  # Directory containing the template files

    # Find all .template files and show proposed changes
    find "$dir" -type f -name '*.template' | while IFS= read -r template_file; do
        echo "Debugging template: $template_file"

        # Read each line in the template file
        while IFS= read -r line; do
            # Attempt to replace placeholders with environment variable values
            modified_line="$line"
            for var_name in $(compgen -v); do
                # Construct the placeholder pattern based on the variable name
                placeholder="{$var_name}"
                # Check if the current line contains the placeholder
                if [[ "$modified_line" == *"$placeholder"* ]]; then
                    # Replace placeholder with the value of the environment variable
                    modified_line="${modified_line//${placeholder}/${!var_name}}"
                fi
            done
            echo "$modified_line"
        done < "$template_file"
    done
}

process_and_replace_templates() {
    local dir="$1"  # Directory containing the template files

    # Find all .template files and process them
    find "$dir" -type f -name '*.template' | while IFS= read -r template_file; do
        echo "Processing template: $template_file"

        # The path for the new file without the .template suffix
        local new_file_path="${template_file%.template}"

        # Read each line in the template file, look for placeholders to replace, and write to new file
        while IFS= read -r line; do
            modified_line="$line"
            # Iterate over all defined variables to check for a match within placeholders
            for var_name in $(compgen -v); do
                placeholder="{${var_name}}"
                # Check if the line contains the current placeholder
                if [[ "$modified_line" == *"${placeholder}"* ]]; then
                    # Fetch the value of the variable by name
                    local var_value="${!var_name}"
                    # Replace the placeholder with the variable's value
                    modified_line="${modified_line//${placeholder}/${var_value}}"
                fi
            done
            # Write the modified line to the new file
            echo "$modified_line" >> "$new_file_path"
        done < "$template_file"

        # Optionally, remove the original .template file if needed
        rm "$template_file"

        echo "Processed and saved to: $new_file_path"
    done
}

build_and_push_image() {
    local service_dir="$1"  # Directory name of the service
    local ecr_repo_url="$2"  # ECR Repository URL for the service
    local image_version="0.1"  # Define your image version here

    # Navigate to the service directory
    cd "${clone_dir}/${service_dir}" || exit

    echo "Building and pushing Docker image for ${service_dir}..."

    # Log in to Amazon ECR
    aws ecr get-login-password --region "$aws_region" | \
        helm registry login --username AWS --password-stdin "$account_id.dkr.ecr.$aws_region.amazonaws.com"

    # Build the Docker image with a specific tag and for a specific platform
    docker buildx build --platform linux/amd64 --build-arg aws_region=$aws_region -t "${ecr_repo_url}:${image_version}" . --load

    # Push the Docker image to Amazon ECR
    docker push "${ecr_repo_url}:${image_version}"

    echo "Image for ${service_dir} pushed successfully."
}

# Script starts here
repo_root="../.." # This could be a parameter
clone_dir="/tmp" # No need to put / eg. /tmp/
terraform_output="./output.json"

export_simple_outputs "$terraform_output"

# Clone Git repositories
git_list="$codecommit_repository_urls_consumer $codecommit_repository_urls_payments $codecommit_repository_urls_producer $aws_codecommit_flux_clone_url_ssh"
clone_git_repos "$git_list" $clone_dir

# Copy folders to cloned repos as is
cp -r $repo_root/tenant-microsservices/consumer/* $clone_dir/consumer
cp -r $repo_root/tenant-microsservices/payments/* $clone_dir/payments
cp -r $repo_root/tenant-microsservices/producer/* $clone_dir/producer
cp -r $repo_root/* $clone_dir/eks-saas-gitops
cp -r $repo_root/.gitignore $clone_dir/eks-saas-gitops

# Process templates in cloned repos
repo_dir="$clone_dir/eks-saas-gitops"
process_and_replace_templates "$repo_dir"

# Push images to Amazon ECR
original_dir="$PWD"

# Helm Chart for Tenant
echo "Packaging and Pushing Helm Chart to ECR"
cd $repo_dir/ || exit
aws ecr get-login-password --region "$aws_region" | helm registry login --username AWS --password-stdin $account_id.dkr.ecr.$aws_region.amazonaws.com
helm package tenant-chart
helm push helm-tenant-chart-0.0.1.tgz oci://$ecr_helm_chart_url_base
cd "$original_dir" || exit

# Docker images for consumer, producer and payments
build_and_push_image "consumer" "$ecr_repository_urls_consumer"
build_and_push_image "producer" "$ecr_repository_urls_producer"
build_and_push_image "payments" "$ecr_repository_urls_payments"
build_and_push_image "eks-saas-gitops/workflow-scripts" "$ecr_argoworkflow_container"
cd "$original_dir" || exit

# Commit and push changes to Git
echo "Committing and pushing changes to Git"
cd $clone_dir/consumer || exit
git add .
git commit -m "Initial Commit"
git push origin main

cd $clone_dir/producer || exit
git add .
git commit -m "Initial Commit"
git push origin main

cd $clone_dir/payments || exit
git add .
git commit -m "Initial Commit"
git push origin main

cd $clone_dir/eks-saas-gitops || exit
git add .
git commit -m "Initial Commit"
git push origin main
# Tagging last commit ID
LAST_COMMIT_ID=$(aws codecommit get-branch --repository-name "$cluster_name" --branch-name main | jq -r '.branch.commitId')
git tag v0.0.1 $LAST_COMMIT_ID
git push origin v0.0.1
cd "$original_dir" || exit

# Creating known hosts for Flux, use in terraform:
ssh-keyscan "git-codecommit.$aws_region.amazonaws.com" > temp_known_hosts