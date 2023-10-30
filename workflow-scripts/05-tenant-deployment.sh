release_version="$1"
tenant_model="$2"
git_user_email="$3"
git_user_name="$4"
REPOSITORY_BRANCH="$5"

MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/"
POOLED_ENVS="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/pooled-envs/"

for TENANT_FILE in $(ls $MANIFESTS_PATH/tenant*)
  do
    if [[ "$TENANT_FILE" == *"hybrid"* && "$tenant_model" == "hybrid" ]]; then
      sed -i "s|version:.*|version: ${release_version}.x|g" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"silo"* && "$tenant_model" == "silo" ]]; then
      sed -i "s|version:.*|version: ${release_version}.x|g" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"pool"* && "$tenant_model" == "pool" ]]; then
      sed -i "s|version:.*|version: ${release_version}.x|g" "${TENANT_FILE}"
    fi
done

if [[ $tenant_model == "pool" ]]; then
  for POOLED_ENV in $(ls $POOLED_ENVS/pool-*)
    do sed -i "s|version:.*|version: ${release_version}.x|g" "${POOLED_ENV}"
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

git status
git add .
git commit -am "Deploying to tenant of $tenant_model in version $release_version"
git push origin $REPOSITORY_BRANCH
