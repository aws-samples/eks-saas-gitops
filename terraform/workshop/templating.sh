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

    find "$dir" -type f -name '*.template' | while IFS= read -r template_file; do
        echo "Processing template: $template_file"

        local new_file_path="${template_file%.template}"
        local temp_file="${new_file_path}.tmp"

        # Ensure the temp file is empty
        > "$temp_file"

        # Ensure the last line is read even if it doesn't end with a newline
        while IFS= read -r line || [[ -n "$line" ]]; do
            modified_line="$line"
            for var_name in $(compgen -v); do
                placeholder="{${var_name}}"
                if [[ "$modified_line" == *"${placeholder}"* ]]; then
                    local var_value="${!var_name}"
                    modified_line="${modified_line//${placeholder}/${var_value}}"
                fi
            done
            echo "$modified_line" >> "$temp_file"
        done < "$template_file"

        # Move the temp file to the new file path
        mv "$temp_file" "$new_file_path"

        echo "Processed and saved to: $new_file_path"

        # Delete the original template file
        rm -f "$template_file"

        echo "Deleted original template file: $template_file"
    done
}

build_and_push_image() {
    local service_dir="$1"  # Directory name of the service
    local ecr_repo_url="$2"  # ECR Repository URL for the service
    local image_version="0.1"  # Define your image version here

    # Navigate to the service directory
    cd "${clone_dir}/${service_dir}" || exit

    echo "Building and pushing Docker image for ${service_dir}..."

    # Log in to Amazon ECR, region is outputed on terraform output
    aws ecr get-login-password --region "$aws_region" | docker login --username AWS --password-stdin "$account_id".dkr.ecr."$aws_region".amazonaws.com

    if [ $(uname -m) = "arm64" ]; then
        # Build the Docker image with a specific tag and for a specific platform
        docker buildx build --platform linux/amd64 --build-arg aws_region=$aws_region -t "${ecr_repo_url}:${image_version}" . --load
    else 
    # Build without buildx for non-ARM
        docker build --build-arg aws_region=$aws_region -t "${ecr_repo_url}:${image_version}" .
    fi

    # Push the Docker image to Amazon ECR
    docker push "${ecr_repo_url}:${image_version}"

    echo "Image for ${service_dir} pushed successfully."
}

package_and_push_helm_chart() {
    local chart_dir="$1"  # Directory of the Helm Chart
    local chart_name="$2"  # Name of the Helm Chart
    local ecr_chart_url="$3"  # ECR URL to push the Helm Chart

    echo "Packaging and Pushing Helm Chart $chart_name to ECR"
    cd "$chart_dir" || exit
    aws ecr get-login-password --region "$aws_region" | helm registry login --username AWS --password-stdin $account_id.dkr.ecr.$aws_region.amazonaws.com
    helm package "$chart_name"
    helm_chart_version=$(grep 'version:' "$chart_name/Chart.yaml" | awk '{print $2}')
    helm push "${chart_name}-${helm_chart_version}.tgz" oci://$ecr_chart_url
    cd - > /dev/null 2>&1 || return
}

# Script starts here
repo_root="../.." # This could be a parameter
clone_dir="$1" # No need to put / eg. /tmp/
terraform_output="./output.json"

export_simple_outputs "$terraform_output"

# Clone Git repositories
git_list="$codecommit_repository_urls_consumer $codecommit_repository_urls_payments $codecommit_repository_urls_producer $aws_codecommit_flux_clone_url_ssh"
clone_git_repos "$git_list" $clone_dir

# Copy folders to cloned repos as is
cp -r $repo_root/tenant-microservices/consumer/* $clone_dir/consumer
cp -r $repo_root/tenant-microservices/payments/* $clone_dir/payments
cp -r $repo_root/tenant-microservices/producer/* $clone_dir/producer
cp -r $repo_root/* $clone_dir/eks-saas-gitops
cp $repo_root/.gitignore $clone_dir/eks-saas-gitops/.gitignore

# Process templates in cloned repos
repo_dir="$clone_dir/eks-saas-gitops"
process_and_replace_templates "$repo_dir"

original_dir="$PWD"

# Package and push Helm Charts to ECR
package_and_push_helm_chart "$repo_dir/helm-charts" "helm-tenant-chart" "$ecr_helm_chart_url_base"
package_and_push_helm_chart "$repo_dir/helm-charts" "application-chart" "$ecr_helm_chart_url_base"

# Docker images for consumer, producer and payments
build_and_push_image "consumer" "$ecr_repository_urls_consumer"
build_and_push_image "producer" "$ecr_repository_urls_producer"
build_and_push_image "payments" "$ecr_repository_urls_payments"
build_and_push_image "eks-saas-gitops/workflow-scripts" "$ecr_argoworkflow_container"
cd "$original_dir" || exit

# Commit and push changes to Git
echo "Committing and pushing changes to Git"
cd $clone_dir/consumer || exit
git checkout -b main
git add .
git commit -m "Initial Commit"
git push origin main

cd $clone_dir/producer || exit
git checkout -b main
git add .
git commit -m "Initial Commit"
git push origin main

cd $clone_dir/payments || exit
git checkout -b main
git add .
git commit -m "Initial Commit"
git push origin main

# remove unnecessary folders from cloud9 before pushing to CodeCommit
rm -rf $clone_dir/eks-saas-gitops/helpers
rm -rf $clone_dir/eks-saas-gitops/tenant-microservices

cd $clone_dir/eks-saas-gitops || exit
git checkout -b main
git add .
git commit -m "Initial Commit"
git push origin main
# Tagging last commit ID
LAST_COMMIT_ID=$(aws codecommit get-branch --repository-name "$cluster_name" --branch-name main | jq -r '.branch.commitId')
git tag v0.0.1 $LAST_COMMIT_ID
git push origin v0.0.1
cd "$original_dir" || exit