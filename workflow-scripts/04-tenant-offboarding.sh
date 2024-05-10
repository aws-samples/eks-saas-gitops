#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
manifests_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants"

main() {
    local tenant_id="$1"
    local tenant_tier="$2"
    local git_user_email="$3"
    local git_user_name="$4"
    local repository_branch="$5"

    # remove tenant helm release file and update kustomization
    remove_tenant_helm_release "${tenant_id}" "${tenant_tier}"

    # configure git user and ssh key so we can push changes to the gitops repo
    configure_git "${git_user_email}" "${git_user_name}"

    # push updated helm releases
    commit_files "${repository_branch}" "${tenant_tier}"
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
    sed -i "/- ${tenant_id}\.yaml/d" "${manifests_path}/${tenant_tier}/kustomization.yaml"
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
    git commit -am "Removing tenant ${tenant_id} in tier ${tenant_tier}"
    git push origin "${repository_branch}"
}

main "$@"
