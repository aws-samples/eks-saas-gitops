release_version="$1"
tenant_model="$2"
git_user_email="$3"
git_user_name="$4"
REPOSITORY_BRANCH="$5"

MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/"
POOLED_ENVS="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/pooled-envs/"
TENANT_TF_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/production/environments"

TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/templates/"
TENANT_HYBRID_TEMPLATE_FILE="${TEMPLATE_PATH}/TENANT_TEMPLATE_HYBRID.yaml"
TENANT_POOL_TEMPLATE_FILE="${TEMPLATE_PATH}/TENANT_TEMPLATE_POOL.yaml"
TENANT_POOL_ENV_TEMPLATE_FILE="${TEMPLATE_PATH}/TENANT_TEMPLATE_POOL_ENV.yaml"
TENANT_SILO_TEMPLATE_FILE="${TEMPLATE_PATH}/TENANT_TEMPLATE_SILO.yaml"

for TENANT_FILE in $(ls $MANIFESTS_PATH/tenant*)
  do
    TENANT_ID=$(echo $TENANT_FILE | tr '/' '\n' | tail -n1 | cut -d '-' -f1,2)
    if [[ "$TENANT_FILE" == *"hybrid"* && "$tenant_model" == "hybrid" ]]; then
      cp "$TENANT_HYBRID_TEMPLATE_FILE" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"silo"* && "$tenant_model" == "silo" ]]; then
      cp "$TENANT_SILO_TEMPLATE_FILE" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"pool"* && "$tenant_model" == "pool" ]]; then
      cp "$TENANT_POOL_TEMPLATE_FILE" "${TENANT_FILE}"
    fi
    cd $TENANT_TF_PATH || exit 1
    terraform output -json | jq ".\"$TENANT_ID\".\"value\"" | yq e -P - | sed 's/^/      /' > ./infra_outputs.yaml
    sed -i '/infraValues:/r ./infra_outputs.yaml' "$TENANT_FILE"
    rm -rf ./infra_outputs.yaml
    sed -i "s|{TENANT_ID}|$TENANT_ID|g" "$TENANT_FILE"
    sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${TENANT_FILE}"
done

if [[ $tenant_model == "pool" ]]; then
  for POOLED_ENV in $(ls $POOLED_ENVS/pool-*)
    do
      ENVIRONMENT_ID=$(echo $POOLED_ENV | tr '/' '\n' | tail -n1 | cut -d '.' -f1)
      cp "$TENANT_POOL_ENV_TEMPLATE_FILE" "${POOLED_ENV}"
      sed -i "s|{ENVIRONMENT_ID}|$ENVIRONMENT_ID|g" "${POOLED_ENV}"
      sed -i "s|{RELEASE_VERSION}|${release_version}|g" "${POOLED_ENV}"
      cd $TENANT_TF_PATH || exit 1
      terraform output -json | jq ".\"$ENVIRONMENT_ID\".\"value\"" | yq e -P - | sed 's/^/      /' > ./infra_outputs.yaml
      sed -i '/infraValues:/r ./infra_outputs.yaml' "${POOLED_ENV}"
      rm -rf ./infra_outputs.yaml
  done
fi

cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
  User ${git_user_name}
  IdentityFile /root/.ssh/id_rsa
EOF

chmod 600 /root/.ssh/config

git config --global user.email "${git_user_email}"
git config --global user.name "${git_user_name}"

cd /mnt/vol/eks-saas-gitops/
git status
git add .
git commit -am "Deploying to tenant of $tenant_model in version $release_version"
git push origin $REPOSITORY_BRANCH
