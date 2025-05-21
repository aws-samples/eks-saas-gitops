#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
repo_root_path="/mnt/vol/eks-saas-gitops"
manifests_path="${repo_root_path}/application-plane/production/tenants"

main() {
    local tenant_id="$1"
    local tenant_tier="$2"
    local git_user_email="$3"
    local git_user_name="$4"
    local repository_branch="$5"
    local git_token="$6"

    # remove tenant helm release file and update kustomization
    remove_tenant_helm_release "${tenant_id}" "${tenant_tier}"

    # configure git user
    # configure_git "${git_user_email}" "${git_user_name}" "${git_token}"

    # Configure git user
    git config --global user.email "${git_user_email}"
    git config --global user.name "${git_user_name}"
    echo "DEBUG: Git user configured"

    # push updated helm releases
    commit_files "${repository_branch}" "${tenant_tier}" "${tenant_id}" "${git_user_name}" "${git_token}"
}

remove_tenant_helm_release() {  
    local tenant_id="$1"
    local tenant_tier="$2"

    # tenant helm release file name based on tenant_tier and tenant_id e.g. (premium/tenant-1.yaml)
    local tenant_manifest_file="${tenant_tier}/${tenant_id}.yaml"

    # full path for tenant helm release file    
    local tenant_manifest_path="${manifests_path}/${tenant_manifest_file}"
    
    # remove tenant helm release file
    rm "${tenant_manifest_path}"

    # update kustomization file by removing the tenant helm release file
    sed -i "/- ${tenant_id}\\.yaml/d" "${manifests_path}/${tenant_tier}/kustomization.yaml"
}

configure_git() {
    local git_user_email="$1"
    local git_user_name="$2"
    local git_token="$3"
    git config --global user.email "${git_user_email}"
    git config --global user.name "${git_user_name}"
    
    # Configure Git to use the provided credentials directly
    git config --global credential.helper 'store --file=/tmp/git-credentials'
    
    # Get the original URL and extract host with port
    REPO_URL=$(git -C ${repo_root_path} remote get-url origin)
    HOST_WITH_PORT=$(echo "$REPO_URL" | sed -E 's|^http://||' | cut -d'/' -f1)
    
    # Store credentials with correct format
    echo "http://${git_user_name}:${git_token}@${HOST_WITH_PORT}" > /tmp/git-credentials
    chmod 600 /tmp/git-credentials
}

commit_files() {
    local repository_branch="$1"
    local tenant_tier="$2"
    local tenant_id="$3"
    local git_user_name="$4"
    local git_token="$5"
    
    cd ${repo_root_path} || exit 1
    git status
    git add .
    git commit -am "Removing tenant ${tenant_id} in tier ${tenant_tier}"
    
    # Get the original URL
    REPO_URL=$(git -C ${repo_root_path} remote get-url origin)
    
    # Check if URL already has credentials
    if [[ "$REPO_URL" == *"@"* ]]; then
        # URL already has credentials, use it directly
        AUTH_URL="$REPO_URL"
    else
        # Extract protocol and domain from URL
        PROTOCOL_AND_DOMAIN=$(echo $REPO_URL | grep -o "^[^/]*//[^/]*")
        
        # Create URL with authentication
        AUTH_URL="${PROTOCOL_AND_DOMAIN/\/\//\/\/$git_user_name:$git_token@}$(echo $REPO_URL | sed "s|^[^/]*//[^/]*||")"
        
        # Set the authenticated URL as the origin
        git remote set-url origin "$AUTH_URL"
    fi
    
    # Push changes
    git push origin "${repository_branch}"
}

main "$@"
