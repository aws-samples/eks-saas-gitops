# Set the desired values for AWS_REGION, TENANT_ID, TENANT_MODEL
TENANT_MODEL="$1"
git_user_email="$2"
git_user_name="$3"
REPOSITORY_BRANCH="$4"

# Define the filename of the Terraform script
TENANT_TF_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/production/environments"
TENANT_TF_TEMPLATE_PATH="/mnt/vol/eks-saas-gitops/terraform/application-plane/templates"

TERRAFORM_SCRIPT_TEMPLATE_SILO="${TENANT_TF_TEMPLATE_PATH}/silo-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_HYBRID="${TENANT_TF_TEMPLATE_PATH}/hybrid-template.tf.template"
TERRAFORM_SCRIPT_TEMPLATE_POOL="${TENANT_TF_TEMPLATE_PATH}/pool-template.tf.template"

for TENANT_FILE in $(ls $TENANT_TF_PATH/tenant*)
  do
    if [[ "$TENANT_FILE" == *"hybrid"* ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_HYBRID" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"silo"* ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_SILO" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"pool"* ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_POOL" "${TENANT_FILE}"
    fi
done

# Perform sed replacements based on the platform
if [[ "$OSTYPE" == "darwin"* ]]; then
  for TENANT_ID in $(cd $TENANT_TF_PATH; ls tenant* | cut -d- -f1,2)
    do
      sed -i "" "s|__TENANT_ID__|$TENANT_ID|g" $TENANT_TF_PATH/*.tf
    done
else
  for TENANT_ID in $(cd $TENANT_TF_PATH; ls tenant* | cut -d- -f1,2)
    do
      sed -i "s|__TENANT_ID__|$TENANT_ID|g" $TENANT_TF_PATH/*.tf
    done
fi

echo "Replacements completed successfully."
echo "Running Terraform..."

cd "$TENANT_TF_PATH"

cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
  User ${git_user_name}
  IdentityFile /root/.ssh/id_rsa
EOF

chmod 600 /root/.ssh/config

git config --global user.email "${git_user_email}"
git config --global user.name "${git_user_name}"

terraform init
terraform plan
terraform apply -auto-approve

git status
git add .
git commit -m "Adding new infra for tenant $TENANT_ID in model $TENANT_MODEL"
git push origin $REPOSITORY_BRANCH