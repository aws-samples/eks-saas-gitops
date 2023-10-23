# Set the desired values for AWS_REGION, TENANT_ID, TENANT_MODEL
TENANT_ID="$1"
TENANT_MODEL="$2"
git_user_email="$3"
git_user_name="$4"
REPOSITORY_BRANCH="$5"

# Define the filename of the Terraform script
TENANT_TF_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/production/environments"
TENANT_TF_TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/templates"

TERRAFORM_SCRIPT_TEMPLATE_SILO="${TENANT_TF_TEMPLATE_PATH}/silo-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_HYBRID="${TENANT_TF_TEMPLATE_PATH}/hybrid-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_POOL="${TENANT_TF_TEMPLATE_PATH}/pool-template.tf.template"

TERRAFORM_SCRIPT="${TENANT_TF_PATH}/${TENANT_ID}-${TENANT_MODEL}.tf"

if [ "$TENANT_MODEL" == "hybrid" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_HYBRID" "$TERRAFORM_SCRIPT"
elif [ "$TENANT_MODEL" == "silo" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_SILO" "$TERRAFORM_SCRIPT"
elif [ "$TENANT_MODEL" == "pool" ]; then
    cp "$TERRAFORM_SCRIPT_TEMPLATE_POOL" "$TERRAFORM_SCRIPT"
fi

echo "$TERRAFORM_SCRIPT"

# Perform sed replacements based on the platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "s/__TENANT_ID__/$TENANT_ID/g" "$TERRAFORM_SCRIPT"
else
    sed -i "s/__TENANT_ID__/$TENANT_ID/g" "$TERRAFORM_SCRIPT"
fi

echo "Replacements completed successfully."
echo "Running Terraform..."

cd "$TENANT_TF_PATH"

terraform init
terraform plan
terraform apply -auto-approve

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
git commit -m "Adding new infra for tenant $TENANT_ID in model $TENANT_MODEL"
git push origin $REPOSITORY_BRANCH