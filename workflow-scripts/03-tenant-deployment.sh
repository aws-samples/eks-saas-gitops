#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
tier_templates_path="/mnt/vol/eks-saas-gitops/application-plane/production/tier-templates"
manifests_path="/mnt/vol/eks-saas-gitops/application-plane/production/tenants"
pooled_envs_path="/mnt/vol/eks-saas-gitops/application-plane/production/pooled-envs"
pool_env_template_file="${tier_templates_path}/basic_env_template.yaml"

main() {
    local release_version="$1"
    local tenant_tier="$2"
    local git_user_email="$3"
    local git_user_name="$4"
    local repository_branch="$5"
    local git_token="$6"

    # get tier template file based on the tier for the tenant being deployed
    # (e.g. /mnt/vol/eks-saas-gitops/gitops/application-plane/production/tier-templates/premium_tenant_template.yaml)
    local tier_template_file
    tier_template_file=$(get_tier_template_file "$tenant_tier")

    # update tenant helm releases for a given tier
    update_tenants "$release_version" "$tier_template_file" "$tenant_tier"
    
    # if tier is basic, update helm release for basic pool environment
    if [[ $tenant_tier == "basic" ]]; then
        update_pool_envs "$release_version"
    fi

    # configure git user
    configure_git "${git_user_email}" "${git_user_name}" "${git_token}"

    # push updated helm releases
    commit_files "${repository_branch}" "${tenant_tier}" "${git_user_name}" "${git_token}"
}

get_tier_template_file() {
    local tenant_tier="$1"    
    case "$tenant_tier" in
        "basic") echo "${tier_templates_path}/basic_tenant_template.yaml" ;;
        "premium") echo "${tier_templates_path}/premium_tenant_template.yaml" ;;
        "advanced") echo "${tier_templates_path}/advanced_tenant_template.yaml" ;;
        *) echo "Invalid tenant tier $tenant_tier"; exit 1 ;;
    esac
}

update_deployment_files() {
    local release_version="$1"
    local template_file="$2"
    local manifests_folder="$3"

    # loop through all tenant helm releases, recreate each file with template, and substitute release version
    for release_file in "${manifests_folder}"/*; do
         if [[ "$release_file" != *kustomization.yaml && "$release_file" != *dummy-configmap.yaml ]]; then #kustomization file doesn't need to change
            local id
            id=$(basename "$release_file" | cut -d '.' -f1)
            cp "$template_file" "${release_file}"
            sed -i "s|{TENANT_ID}|$id|g" "$release_file"
            sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${release_file}"
        fi
    done
}

update_pool_envs() {    
    local release_version="$1"
    local pool_env="pool-1" # This should be dynamic to allow creation of multiple pool environments, for testing and shard tenants
    update_deployment_files "$release_version" "$pool_env_template_file" "$pooled_envs_path"
    sed -i "s|{ENVIRONMENT_ID}|$pool_env|g" "${pooled_envs_path}/${pool_env}.yaml"
}

update_tenants() {    
    local release_version="$1"
    local template_file="$2"
    local tenant_tier="$3"    
    update_deployment_files "$release_version" "$template_file" "${manifests_path}/${tenant_tier}"
}

configure_git() {
    local git_user_email="$1"
    local git_user_name="$2"
    local git_token="$3"
    git config --global user.email "${git_user_email}"
    git config --global user.name "${git_user_name}"
    
    # Store credentials for HTTPS
    git config --global credential.helper store
    echo "https://${git_user_name}:${git_token}@$(echo $REPO_URL | sed 's|https://||')" > ~/.git-credentials
    chmod 600 ~/.git-credentials
}

commit_files() {
    local repository_branch="$1"
    local tenant_tier="$2"
    local git_user_name="$3"
    local git_token="$4"
    
    cd /mnt/vol/eks-saas-gitops/ || exit 1
    git status
    git add .
    git commit -am "Deploying to $tenant_tier tenants, version $release_version"
    
    # Extract protocol and domain from remote URL
    REPO_URL=$(git remote get-url origin)
    PROTOCOL_AND_DOMAIN=$(echo $REPO_URL | grep -o "^[^/]*//[^/]*")
    
    # Create URL with authentication
    AUTH_URL="${PROTOCOL_AND_DOMAIN/\/\//\/\/$git_user_name:$git_token@}$(echo $REPO_URL | sed "s|^[^/]*//[^/]*||")"
    
    # Set the authenticated remote URL and push
    git remote set-url origin "$AUTH_URL"
    git push origin "${repository_branch}"
}

main "$@"