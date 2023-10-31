tenant_id="$1"
major_version="$2"
tenant_model="$3"
git_user_email="$4"
git_user_name="$5"
REPOSITORY_BRANCH="$6"

TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/templates"
MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/"

TENANT_HYBRID_TEMPLATE_FILE="TENANT_TEMPLATE_HYBRID.yaml"
TENANT_POOL_TEMPLATE_FILE="TENANT_TEMPLATE_POOL.yaml"
TENANT_SILO_TEMPLATE_FILE="TENANT_TEMPLATE_SILO.yaml"


TENANT_MANIFEST_FILE="${tenant_id}-${tenant_model}.yaml"

# Create new manifests for the tenant using TENANT_TEMPLATE_FILE, check if tenant_model is pooled or siloed, and update the manifests accordingly
if [ "$tenant_model" == "pool" ]; then
    cd  $TEMPLATE_PATH || exit 1
    sed -e "s|{TENANT_ID}|${tenant_id}|g" "${TENANT_POOL_TEMPLATE_FILE}" > ${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}
    sed -i "s|{MAJOR_VERSION}|${major_version}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    # append a new line in kustomization.yaml file using $TENANT_MANIFEST_FILE
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> ${MANIFESTS_PATH}kustomization.yaml
    cd ../../../

elif [ "$tenant_model" == "silo" ]; then
    cd  $TEMPLATE_PATH || exit 1
    sed -e "s|{TENANT_ID}|${tenant_id}|g" "${TENANT_SILO_TEMPLATE_FILE}" > ${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}
    sed -i "s|{MAJOR_VERSION}|${major_version}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    sed -i "s|{SQS_QUEUE_ARN}|${SQS_QUEUE_ARN}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    sed -i "s|{DDB_TABLE_ARN}|${DDB_TABLE_ARN}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> ${MANIFESTS_PATH}kustomization.yaml
    cd ../../../

elif [ "$tenant_model" == "hybrid" ]; then
    cd  $TEMPLATE_PATH || exit 1
    sed -e "s|{TENANT_ID}|${tenant_id}|g" "${TENANT_HYBRID_TEMPLATE_FILE}" > ${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}
    sed -i "s|{MAJOR_VERSION}|${major_version}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    sed -i "s|{SQS_QUEUE_ARN}|${SQS_QUEUE_ARN}|g" "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
    printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> ${MANIFESTS_PATH}kustomization.yaml
    cd ../../../
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