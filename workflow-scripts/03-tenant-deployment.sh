#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
tier_templates_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tier-templates"
manifests_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants"
pooled_envs_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/pooled-envs"
pool_env_template_file="${tier_templates_path}/basic_env_template.yaml"

main() {
    release_version="$1"
    tenant_tier="$2"
    git_user_email="$3"
    git_user_name="$4"
    repository_branch="$5"

    # get tier template file based on the tier for the tenant being deployed
    # (e.g. /mnt/vol/eks-saas-gitops/gitops/application-plane/production/tier-templates/premium_tenant_template.yaml)
    local tier_template_file
    tier_template_file=$(get_tier_template_file "$tenant_tier")

    # if tier is basic, update helm release for basic pool environment
    if [[ $tenant_tier == "basic" ]]; then
        update_pool_envs "$release_version"
    fi

    # update tenant helm releases for a given tier
    update_tenants "$release_version" "$tier_template_file"

    # configure git user and ssh key so we can push changes to the gitops repo
    configure_git "${git_user_email}" "${git_user_name}"

    # push updated helm releases
    commit_files "${repository_branch}" "${tenant_tier}"
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

update_pool_envs() {
    local release_version="$1"

    # loop through all pooled_envs helm releases, recreate each file with template, and substitute release version
    for pooled_env in "${pooled_envs_path}"/pool-*; do
        local environment_id
        environment_id=$(basename "$pooled_env" | cut -d '.' -f1)
        cp "$pool_env_template_file" "$pooled_env"
        sed -i "s|{ENVIRONMENT_ID}|${environment_id}|g; s|{RELEASE_VERSION}|${release_version}|g" "$pooled_env"
    done
}

update_tenants() {
    local release_version="$1"
    local template_file="$2"

    # loop through all tenant helm releases, recreate each file with template, and substitute release version
    for tenant_file in "${manifests_path}/${tenant_tier}"/*; do
        local tenant_id
        tenant_id=$(basename "$tenant_file" | cut -d '.' -f1)
        cp "$template_file" "${tenant_file}"
        sed -i "s|{TENANT_ID}|$tenant_id|g" "$tenant_file"
        sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${tenant_file}"
    done
}

configure_git() {
    local git_user_email="$1"
    local git_user_name="$2"
    git config --global user.email "${git_user_email}"
    git config --global user.name "${git_user_name}"
    cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
    User ${git_user_name}
    IdentityFile /root/.ssh/id_rsa
EOF
    chmod 600 /root/.ssh/config
}

commit_files() {
    local repository_branch="$1"
    local tenant_tier="$2"
    cd /mnt/vol/eks-saas-gitops/ || exit 1
    git status
    git add .
    git commit -am "Deploying to $tenant_tier tenants, version $release_version"
    git push origin "${repository_branch}"
}

main "$@"
