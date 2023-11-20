#!/bin/bash
# Parameter passed in from the Sensor when Workflow is created
TENANT_ID="$1"
TENANT_MODEL="$2"
GIT_USER_EMAIL="$3"
GIT_USER_NAME="$4"
REPOSITORY_BRANCH="$5"

# Volumes mounted from git clone step
TENANT_TF_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/production/environments"
TENANT_TF_TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/templates"

# Tier template files
TERRAFORM_SCRIPT_TEMPLATE_SILO="${TENANT_TF_TEMPLATE_PATH}/silo-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_HYBRID="${TENANT_TF_TEMPLATE_PATH}/hybrid-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_POOL="${TENANT_TF_TEMPLATE_PATH}/pool-template.tf.template"
TERRAFORM_SCRIPT="${TENANT_TF_PATH}/${TENANT_ID}-${TENANT_MODEL}.tf"

# Determine which model template to use
if [ "$TENANT_MODEL" == "hybrid" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_HYBRID" "$TERRAFORM_SCRIPT"
elif [ "$TENANT_MODEL" == "silo" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_SILO" "$TERRAFORM_SCRIPT"
elif [ "$TENANT_MODEL" == "pool" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_POOL" "$TERRAFORM_SCRIPT"
fi

# Creates new deployment file
sed -i "s|__TENANT_ID__|$TENANT_ID|g" "$TERRAFORM_SCRIPT"

# Configure code-commit locally - terraform needs to pull ref version
cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
    User ${GIT_USER_NAME}
    IdentityFile /root/.ssh/id_rsa
EOF
chmod 600 /root/.ssh/config
git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "${GIT_USER_NAME}"

# Apply terraform
echo "Applying Terraform..."
cd "$TENANT_TF_PATH" || exit
terraform init
terraform plan
terraform apply -auto-approve

# Commit files to gitops git repo
git status
git add .
git commit -m "Adding new infra for tenant $TENANT_ID in model $TENANT_MODEL"
git push origin "$REPOSITORY_BRANCH"