tenant_id="$1"
tenant_model="$2"
git_user_email="$3"
git_user_name="$4"
REPOSITORY_BRANCH="$5"

MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants"

TENANT_HYBRID_TEMPLATE_FILE="TENANT_TEMPLATE_HYBRID.yaml"
TENANT_POOL_TEMPLATE_FILE="TENANT_TEMPLATE_POOL.yaml"
TENANT_SILO_TEMPLATE_FILE="TENANT_TEMPLATE_SILO.yaml"


TENANT_MANIFEST_FILE="${tenant_id}-${tenant_model}.yaml"

# Create new manifests for the tenant using TENANT_TEMPLATE_FILE, check if tenant_model is pooled or siloed, and update the manifests accordingly
if [ "$tenant_model" == "pooled" ]; then
    cd  $MANIFESTS_PATH || exit 1
    ls
    cp "$TENANT_POOL_TEMPLATE_FILE" "$TENANT_MANIFEST_FILE" && sed -i "s/TENANT_ID/${tenant_id}/g" "$TENANT_MANIFEST_FILE"
    # append a new line in kustomization.yaml file using $TENANT_MANIFEST_FILE
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> kustomization.yaml
    cd ../../../../

elif [ "$tenant_model" == "siloed" ]; then
    cd  $MANIFESTS_PATH || exit 1
    cp "$TENANT_SILO_TEMPLATE_FILE" "$TENANT_MANIFEST_FILE" && sed -i "s/TENANT_ID/${tenant_id}/g" "$TENANT_MANIFEST_FILE"
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> kustomization.yaml
    cd ../../../../

elif [ "$tenant_model" == "hybrid" ]; then
    cd  $MANIFESTS_PATH || exit 1
    cp "$TENANT_HYBRID_TEMPLATE_FILE" "$TENANT_MANIFEST_FILE" && sed -i "s/TENANT_ID/${tenant_id}/g" "$TENANT_MANIFEST_FILE"
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> kustomization.yaml
    cd ../../../../

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
git commit -am "Adding new tenant $tenant_id in model $tenant_model"
git push origin $REPOSITORY_BRANCH