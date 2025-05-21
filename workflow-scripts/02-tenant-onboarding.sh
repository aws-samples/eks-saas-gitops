#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
repo_root_path="/mnt/vol/eks-saas-gitops"
tier_templates_path="${repo_root_path}/application-plane/production/tier-templates"
manifests_path="${repo_root_path}/application-plane/production/tenants"

main() {
    local tenant_id="$1"
    local release_version="$2"
    local tenant_tier="$3"
    local git_user_email="$4"
    local git_user_name="$5"
    local repository_branch="$6"
    local git_token="$7"

    # get tier template file based on the tier for the tenant being provisioned 
    # (e.g. /mnt/vol/eks-saas-gitops/gitops/application-plane/production/tier-templates/premium_tenant_template.yaml)
    local tier_template_file
    tier_template_file=$(get_tier_template_file "$tenant_tier")
    
    # create the tenant helm release file based on the tier template file and tenant id
    # (e.g. /mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/premium/tenant-1.yaml)
    create_helm_release "$tenant_id" "$tenant_tier" "$release_version" "$tier_template_file"
    
    # configure git user
    # configure_git "${git_user_email}" "${git_user_name}" "${git_token}"

    # push new helm release for the tenant and kustomization update to the gitops repo
    commit_files "${repository_branch}" "${tenant_id}" "${tenant_tier}" "${git_user_name}" "${git_token}"
}

create_helm_release() {    
    local tenant_id="$1"
    local tenant_tier="$2"
    local release_version="$3"
    local tier_template_file="$4"
    
    # tenant helm release file name based on tenant_tier and tenant_id e.g. (premium/tenant-1.yaml)
    local tenant_manifest_file="${tenant_tier}/${tenant_id}.yaml"

    # make a copy of the tier template file onto the tenant helm release file
    cp "${tier_template_file}" "${manifests_path}/${tenant_manifest_file}"
    
    # replace the tenant id and release version in the tenant helm release file
    sed -i "s|{TENANT_ID}|${tenant_id}|g" "${manifests_path}/${tenant_manifest_file}"
    sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${manifests_path}/${tenant_manifest_file}"
    
    # update the kustomization file with the new tenant helm release file
    printf "\n  - %s.yaml" "${tenant_id}" >> "${manifests_path}/${tenant_tier}/kustomization.yaml"    
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
    local tenant_id="$2"
    local tenant_tier="$3"
    local git_user_name="$4"
    local git_token="$5"
    
    cd ${repo_root_path} || exit 1
    git status
    git add .
    git commit -am "Adding new tenant ${tenant_id} in tier ${tenant_tier}"
    
    # Push changes
    echo "Pushing changes..."
    git push origin "${repository_branch}"
}


main "$@"