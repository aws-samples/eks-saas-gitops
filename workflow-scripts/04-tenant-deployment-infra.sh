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
    if [[ "$TENANT_FILE" == *"hybrid"* && "$TENANT_MODEL" == "hybrid" ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_HYBRID" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"silo"* && "$TENANT_MODEL" == "silo" ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_SILO" "${TENANT_FILE}"
    elif [[ "$TENANT_FILE" == *"pool"* && "$TENANT_MODEL" == "pool" ]]; then
      cp "$TERRAFORM_SCRIPT_TEMPLATE_POOL" "${TENANT_FILE}"
    fi
done

for POOLED_ENV in $(ls $TENANT_TF_PATH/pooled-*)
  do 
    if [[ "$POOLED_ENV" == *"pool"* && "$TENANT_MODEL" == "pool" ]]; then
      # This is needed for changed pooled environments
      filename=$TERRAFORM_SCRIPT_TEMPLATE_POOL
      new_version=$(grep -o 'ref=v[0-9]\+\.[0-9]\+\.[0-9]\+' $filename | awk -F= '{print $2}')
      current_version=$(grep -o 'ref=v[0-9]\+\.[0-9]\+\.[0-9]\+' $POOLED_ENV | awk -F= '{print $2}')
      
      echo "Change ${POOLED_ENV} from ${current_version} to new version ${new_version}"
      sed -i "s?ref=$current_version?ref=$new_version?g" $POOLED_ENV
    fi
  done

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
git commit -m "Deploying new infra for model $TENANT_MODEL."
git push origin $REPOSITORY_BRANCH
