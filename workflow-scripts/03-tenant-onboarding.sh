#!/bin/bash
# Parameter passed in from the Sensor when Workflow is created
TENANT_ID="$1"
RELEASE_VERSION="$2"
TENANT_MODEL="$3"
GIT_USER_EMAIL="$4"
GIT_USER_NAME="$5"
REPOSITORY_BRANCH="$6"

# Set directory paths
TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/templates"
MANIFESTS_PATH="/mnt/vol/eks-saas-gitops/gitops/application-plane/production/tenants/"
TENANT_TF_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/production/environments"

# Set template files
TENANT_HYBRID_TEMPLATE_FILE="TENANT_TEMPLATE_HYBRID.yaml"
TENANT_POOL_TEMPLATE_FILE="TENANT_TEMPLATE_POOL.yaml"
TENANT_SILO_TEMPLATE_FILE="TENANT_TEMPLATE_SILO.yaml"
TENANT_MANIFEST_FILE="${TENANT_ID}-${TENANT_MODEL}.yaml"

# Move to the template directory
cd "$TEMPLATE_PATH" || exit 1

# Determine which model template to use
case "$TENANT_MODEL" in
    "pool") TEMPLATE_FILE="${TENANT_POOL_TEMPLATE_FILE}" ;;
    "silo") TEMPLATE_FILE="${TENANT_SILO_TEMPLATE_FILE}" ;;
    "hybrid") TEMPLATE_FILE="${TENANT_HYBRID_TEMPLATE_FILE}" ;;
    *) echo "Invalid TENANT_MODEL"; exit 1 ;;
esac

# Replace TENANT_ID and RELEASE_VERSION in the template to create the tenant Helm release file
sed -e "s|{TENANT_ID}|${TENANT_ID}|g" -e "s|{RELEASE_VERSION}|${RELEASE_VERSION}|g" "${TEMPLATE_FILE}" > "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"

# Add the new file to kustomization.yaml
printf "\n  - ${TENANT_MANIFEST_FILE}\n" >> "${MANIFESTS_PATH}kustomization.yaml"

# Move back to the parent directory
cd ../../../ || exit 1

# Link Terraform output to environment variables
cd $TENANT_TF_PATH || exit 1
terraform output -json | jq ".\"$TENANT_ID\".\"value\"" | yq e -P - | sed 's/^/      /' > ./infra_outputs.yaml
sed -i '/infraValues:/r ./infra_outputs.yaml' "${MANIFESTS_PATH}${TENANT_MANIFEST_FILE}"
rm -rf ./infra_outputs.yaml
cd ../../../../

# Configure SSH for Git
cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
  User ${GIT_USER_NAME}
  IdentityFile /root/.ssh/id_rsa
EOF

chmod 600 /root/.ssh/config

# Configure Git user information
git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "${GIT_USER_NAME}"

# Commit files to GitOps Git repo
git status
git add .
git commit -am "Adding new tenant $TENANT_ID in model $TENANT_MODEL"
git push origin "$REPOSITORY_BRANCH"
