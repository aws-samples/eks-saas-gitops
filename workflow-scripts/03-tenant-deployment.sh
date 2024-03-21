#!/bin/bash

# map templates and helm release folders -- this is mounted on 01-tenant-clone-repo.sh
tier_templates_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tier-templates"
manifests_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants"
pooled_envs_path="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/pooled-envs"

main() {
	release_version="$1"
	tenant_tier="$2"
	git_user_email="$3"
	git_user_name="$4"
	repository_branch="$5"

	# get tier template file based on the tier for the tenant being deployed (e.g. premium_tenant_template.yaml)
	local tier_template_file
	tier_template_file=$(get_tier_template_file "$tenant_tier" "$tier_templates_path")

	if [[ $tenant_tier == "basic" ]]; then
        process_basic_pooled_envs "$release_version" "$pooled_envs_path" "$tier_template_file"
    fi

	# configure git user and ssh key so we can push changes to the gitops repo
	configure_git "${git_user_email}" "${git_user_name}"

	# push new helm release for the tenant and kustomization update to the gitops repo
	commit_files "${repository_branch}" "${tenant_id}" "${tenant_tier}"
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
	# if [[ $tenant_tier == "basic" ]]; then
	# 	for POOLED_ENV in $(ls $POOLED_ENVS/pool-*)
	# 		do
	# 			ENVIRONMENT_ID=$(echo $POOLED_ENV | tr '/' '\n' | tail -n1 | cut -d '.' -f1)
	# 			cp "$TENANT_BASIC_ENV_TEMPLATE" "${POOLED_ENV}"
	# 			sed -i "s|{ENVIRONMENT_ID}|$ENVIRONMENT_ID|g" "${POOLED_ENV}"
	# 			sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${POOLED_ENV}"
	# 		done
	# fi

	local release_version="$1"
    local pooled_envs="$2"
    local template_file="$3"

    for pooled_env in "${pooled_envs}"/pool-*; do
        local environment_id
        environment_id=$(basename "$pooled_env" | cut -d '.' -f1)
        cp "$template_file" "$pooled_env"
        sed -i "s|{ENVIRONMENT_ID}|${environment_id}|g; s|{RELEASE_VERSION}|${release_version}|g" "$pooled_env"
    done
}

update_tenants() {
	for TENANT_FILE in $(ls $MANIFESTS_PATH/tenant*)
		do
			TENANT_ID=$(echo $TENANT_FILE | tr '/' '\n' | tail -n1 | cut -d '-' -f1,2)
			cp "$TEMPLATE_FILE" "${TENANT_FILE}"
			sed -i "s|{TENANT_ID}|$TENANT_ID|g" "$TENANT_FILE"
			sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${TENANT_FILE}"
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
    local tenant_id="$2"
    local tenant_tier="$3"
    cd /mnt/vol/eks-saas-gitops/ || exit 1
    git status
    git add .
    git commit -am "Deploying to $tenant_tier tenants, version $release_version"
    git push origin "${repository_branch}"
}

main "$@"



