#!/bin/bash
# Parameter passed in from the Sensor when Workflow is created
TENANT_ID="$1"
TENANT_MODEL="$2"
GIT_USER_EMAIL="$3"
GIT_USER_NAME="$4"
REPOSITORY_BRANCH="$5"

# Volumes mounted from git clone step
TENANT_INFRA_MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/infrastructure"
TENANT_INFRA_TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/templates/infrastructure"

# Tier template files
INFRA_TEMPLATE_SILO="${TENANT_INFRA_TEMPLATE_PATH}/TENANT_TEMPLATE_SILO_INFRA.yaml"
INFRA_TEMPLATE_HYBRID="${TENANT_INFRA_TEMPLATE_PATH}/TENANT_TEMPLATE_HYBRID_INFRA.yaml"
INFRA_TEMPLATE_POOL="${TENANT_INFRA_TEMPLATE_PATH}/TENANT_TEMPLATE_POOL_INFRA.yaml"

TENANT_INFRA_FILE="${TENANT_INFRA_MANIFESTS_PATH}/${TENANT_ID}-${TENANT_MODEL}.yaml"

# Determine which model template to use
if [ "$TENANT_MODEL" == "hybrid" ]; then
    cp "$INFRA_TEMPLATE_HYBRID" "$TENANT_INFRA_FILE"
elif [ "$TENANT_MODEL" == "silo" ]; then
    cp "$INFRA_TEMPLATE_SILO" "$TENANT_INFRA_FILE"
elif [ "$TENANT_MODEL" == "pool" ]; then
    cp "$INFRA_TEMPLATE_POOL" "$TENANT_INFRA_FILE"
fi

# Creates new infra file
sed -i "s|__TENANT_ID__|$TENANT_ID|g" "$TENANT_INFRA_FILE"

# Add the new file to kustomization.yaml
KUSTOMIZATION_LINE="${TENANT_ID}-${TENANT_MODEL}.yaml"
printf "\n  - ${KUSTOMIZATION_LINE}\n" >> "${TENANT_INFRA_MANIFESTS_PATH}/kustomization.yaml"

# Configure code-commit locally - terraform needs to pull ref version
cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
    User ${GIT_USER_NAME}
    IdentityFile /root/.ssh/id_rsa
EOF
chmod 600 /root/.ssh/config
git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "${GIT_USER_NAME}"

# # Apply terraform
# echo "Applying Terraform..."
# cd "$TENANT_TF_PATH" || exit
# terraform init
# terraform plan
# terraform apply -auto-approve

# Commit files to gitops git repo
cd /mnt/vol/eks-saas-gitops/ || exit
git status
git add .
git commit -m "Adding new infra for tenant $TENANT_ID in model $TENANT_MODEL"
git push origin "$REPOSITORY_BRANCH"