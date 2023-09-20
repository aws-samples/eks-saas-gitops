#!/bin/bash
set -e
trap 'catch_error $? $LINENO' ERR
touch /home/ec2-user/environment/install_errors.txt

catch_error() {
     echo "Error $1 occurred on $2" >> /home/ec2-user/environment/install_errors.txt
}

export AWS_REGION="$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d'"' -f4)"
echo "export AWS_REGION=${AWS_REGION}" >> /root/.bashrc

# APPLY TERRAFORM NO FLUX
cd /home/ec2-user/environment/eks-saas-gitops/terraform/clusters/production

terraform init

MAX_RETRIES=3
COUNT=0
SUCCESS=false

echo "Applying Terraform ..."

while [ $COUNT -lt $MAX_RETRIES ]; do
     terraform apply -var "aws_region=${AWS_REGION}" \
     -target=module.vpc \
     -target=module.eks \
     -target=aws_iam_role.karpenter_node_role \
     -target=aws_iam_policy_attachment.container_registry_policy \
     -target=aws_iam_policy_attachment.amazon_eks_worker_node_policy \
     -target=aws_iam_policy_attachment.amazon_eks_cni_policy \
     -target=aws_iam_policy_attachment.amazon_eks_ssm_policy \
     -target=aws_iam_instance_profile.karpenter_instance_profile \
     -target=module.karpenter_irsa_role \
     -target=aws_iam_policy.karpenter-policy \
     -target=aws_iam_policy_attachment.karpenter_policy_attach \
     -target=module.argo_workflows_eks_role \
     -target=random_uuid.uuid \
     -target=aws_s3_bucket.argo-artifacts \
     -target=module.lb-controller-irsa \
     -target=aws_ecr_repository.tenant_helm_chart \
     -target=aws_ecr_repository.argoworkflow_container \
     -target=aws_ecr_repository.consumer_container \
     -target=aws_ecr_repository.producer_container \
     -target=module.codecommit-flux \
     -target=aws_iam_user.codecommit-user \
     -target=aws_iam_user_policy_attachment.codecommit-user-attach \
     -target=module.ebs_csi_irsa_role \
     -target=aws_s3_bucket.tenant-terraform-state-bucket --auto-approve

     if [ $? -eq 0 ]; then
          echo "Terraform apply succeeded."
          SUCCESS=true
          break
     else
          echo "Terraform apply failed. Retrying..."
          COUNT=$((COUNT+1))
     fi
done

if [ "$SUCCESS" = false ]; then
     echo "Max retries reached for terraform apply."
fi

# Continue with the rest of your script
echo "Exporting terraform output to environment variables"

# Exporting terraform outputs to bashrc
outputs=("argo_workflows_bucket_name" 
         "argo_workflows_irsa" 
         "aws_codecommit_clone_url_http" 
         "aws_codecommit_clone_url_ssh" 
         "aws_vpc_id" 
         "cluster_endpoint" 
         "cluster_iam_role_name" 
         "cluster_primary_security_group_id" 
         "ecr_argoworkflow_container" 
         "ecr_consumer_container" 
         "ecr_helm_chart_url" 
         "ecr_producer_container" 
         "karpenter_instance_profile" 
         "karpenter_irsa" 
         "lb_controller_irsa"
         "tenant_terraform_state_bucket_name")

for output in "${outputs[@]}"; do
    value=$(terraform output -raw $output)
    echo "export ${output^^}=$value" >> /home/ec2-user/.bashrc
    echo "export ${output^^}=$value" >> /root/.bashrc
done

source /root/.bashrc

# Defining variables for CodeCommit
cd /home/ec2-user/environment/

echo "Configuring Cloud9 User to CodeCommit"
ssh-keygen -t rsa -b 4096 -f flux -N ""
aws iam upload-ssh-public-key --user-name codecommit-user --ssh-public-key-body file:///home/ec2-user/environment/flux.pub

ssh_public_key_id=$(aws iam list-ssh-public-keys --user-name codecommit-user --query "SSHPublicKeys[0].SSHPublicKeyId" --output text)
modified_clone_url="ssh://${ssh_public_key_id}@$(echo ${AWS_CODECOMMIT_CLONE_URL_SSH} | cut -d'/' -f3-)"

export CODECOMMIT_USER_ID=$(aws iam list-ssh-public-keys --user-name codecommit-user | jq -r '.SSHPublicKeys[0].SSHPublicKeyId')
echo "export CODECOMMIT_USER_ID=${CODECOMMIT_USER_ID}" >> /home/ec2-user/.bashrc
echo "export CODECOMMIT_USER_ID=${CODECOMMIT_USER_ID}" >> /root/.bashrc

export CLONE_URL_CODECOMMIT_USER=${modified_clone_url}
echo "export CLONE_URL_CODECOMMIT_USER=${CLONE_URL_CODECOMMIT_USER}" >> /home/ec2-user/.bashrc
echo "export CLONE_URL_CODECOMMIT_USER=${CLONE_URL_CODECOMMIT_USER}" >> /root/.bashrc

source /root/.bashrc

# Creating SSH Key for CodeCommit User
ssh-keyscan "git-codecommit.${AWS_REGION}.amazonaws.com" > /home/ec2-user/environment/temp_known_hosts

# Configuring Key for root
cp /home/ec2-user/environment/flux /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa
cat <<EOF > /root/.ssh/config
Host git-codecommit.*.amazonaws.com
  User ${CODECOMMIT_USER_ID}
  IdentityFile /root/.ssh/id_rsa
EOF
chmod 600 /root/.ssh/config
ssh-keyscan "git-codecommit.${AWS_REGION}.amazonaws.com" > /root/.ssh/known_hosts

# Configuring Key for Ec2-User
cp /home/ec2-user/environment/flux /home/ec2-user/.ssh/id_rsa && chmod 600 /home/ec2-user/.ssh/id_rsa
cat <<EOF > /home/ec2-user/.ssh/config
Host git-codecommit.*.amazonaws.com
  User ${CODECOMMIT_USER_ID}
  IdentityFile /home/ec2-user/.ssh/id_rsa
EOF
chmod 600 /home/ec2-user/.ssh/config
ssh-keyscan "git-codecommit.${AWS_REGION}.amazonaws.com" > /home/ec2-user/known_hosts
chown -R ec2-user:ec2-user /home/ec2-user/.ssh/

# Cloning code commit repository and copying files to the git repository
echo "Cloning CodeCommit repository and copying files"

cd /home/ec2-user/environment
source /root/.bashrc

echo "Cloning CodeCommit repository and copying files"
sleep 60

git clone $CLONE_URL_CODECOMMIT_USER

cp -r /home/ec2-user/environment/eks-saas-gitops/* /home/ec2-user/environment/eks-saas-gitops-aws
cp /home/ec2-user/environment/eks-saas-gitops/.gitignore /home/ec2-user/environment/eks-saas-gitops-aws/.gitignore
rm -rf /home/ec2-user/environment/eks-saas-gitops

echo "Create pool-1 application infra"

# Creating pool-1 application infra
export APPLICATION_PLANE_INFRA_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/production/environments"

sed -e "s|{AWS_REGION}|${AWS_REGION}|g" "${APPLICATION_PLANE_INFRA_FOLDER}/providers.tf.template" > ${APPLICATION_PLANE_INFRA_FOLDER}/providers.tf
sed -i "s|{TERRAFORM_STATE_BUCKET}|${TENANT_TERRAFORM_STATE_BUCKET_NAME}|g" "${APPLICATION_PLANE_INFRA_FOLDER}/providers.tf"

cd $APPLICATION_PLANE_INFRA_FOLDER && terraform init && terraform apply -auto-approve

echo "Changing template files to terraform output values"

# Changing template files to use the new values
export GITOPS_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/gitops"
export ONBOARDING_FOLER="/home/ec2-user/environment/eks-saas-gitops-aws/tenant-onboarding"
export TENANT_CHART_FOLER="/home/ec2-user/environment/eks-saas-gitops-aws/tenant-chart"

sed -e "s|{TENANT_CHART_HELM_REPO}|$(echo ${ECR_HELM_CHART_URL} | sed 's|\(.*\)/.*|\1|')|g" "${GITOPS_FOLDER}/infrastructure/base/sources/tenant-chart-helm.yaml.template" > ${GITOPS_FOLDER}/infrastructure/base/sources/tenant-chart-helm.yaml
sed -e "s|{KARPENTER_CONTROLLER_IRSA}|${KARPENTER_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml.template" > ${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml
sed -i "s|{EKS_CLUSTER_ENDPOINT}|${CLUSTER_ENDPOINT}|g" "${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml"
sed -i "s|{KARPENTER_INSTANCE_PROFILE}|${KARPENTER_INSTANCE_PROFILE}|g" "${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml"
sed -e "s|{ARGO_WORKFLOW_IRSA}|${ARGO_WORKFLOWS_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml.template" > "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml"
sed -i "s|{ARGO_WORKFLOW_BUCKET}|${ARGO_WORKFLOWS_BUCKET_NAME}|g" "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml"
sed -e "s|{LB_CONTROLLER_IRSA}|${LB_CONTROLLER_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/04-lb-controller.yaml.template" > ${GITOPS_FOLDER}/infrastructure/production/04-lb-controller.yaml
sed -i "s|{ARGO_WORKFLOW_CONTAINER}|${ECR_ARGOWORKFLOW_CONTAINER}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-onboarding-workflow-template.yaml"

sed -e "s|{CONSUMER_ECR}|${ECR_CONSUMER_CONTAINER}|g" "${TENANT_CHART_FOLER}/values.yaml.template" > ${TENANT_CHART_FOLER}/values.yaml
sed -i "s|{PRODUCER_ECR}|${ECR_PRODUCER_CONTAINER}|g" "${TENANT_CHART_FOLER}/values.yaml"

# Building containers and push to ECR
cd /home/ec2-user/environment/eks-saas-gitops-aws

echo "Push Images to Amazon ECR"

# Build & Push Tenant Helm Chart
aws ecr get-login-password \
     --region $AWS_REGION | helm registry login \
     --username AWS \
     --password-stdin $ECR_HELM_CHART_URL
helm package tenant-chart
helm push helm-tenant-chart-0.0.1.tgz oci://$(echo $ECR_HELM_CHART_URL | sed 's|\(.*\)/.*|\1|')

aws ecr get-login-password \
     --region $AWS_REGION | docker login \
     --username AWS \
     --password-stdin $ECR_PRODUCER_CONTAINER
docker build -t $ECR_PRODUCER_CONTAINER:0.1 tenants-microsservices/producer
docker push $ECR_PRODUCER_CONTAINER:0.1

aws ecr get-login-password \
     --region $AWS_REGION | docker login \
     --username AWS \
     --password-stdin $ECR_CONSUMER_CONTAINER
docker build -t $ECR_CONSUMER_CONTAINER:0.1 tenants-microsservices/consumer
docker push $ECR_CONSUMER_CONTAINER:0.1

aws ecr get-login-password \
     --region $AWS_REGION | docker login \
     --username AWS \
     --password-stdin $ECR_ARGOWORKFLOW_CONTAINER
docker build --build-arg aws_region=${AWS_REGION} -t $ECR_ARGOWORKFLOW_CONTAINER tenant-onboarding
docker push $ECR_ARGOWORKFLOW_CONTAINER

echo "First commit CodeCommit repository"

git checkout -b main
git add .
git commit -m 'Initial Setup'
git push origin main

echo "Configuring Flux and Argo to use SSH Key"
cd /home/ec2-user/environment/

export TERRAFORM_CLUSTER_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/clusters/production"

echo "Creating Flux secret"
# Clear the YAML file if it exists
> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml

# Append the beginning of the file
echo "# Define here your GitHub credentials" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
echo "secret:" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
echo "  create: true" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
echo "  data:" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml

# Append the keys
echo "    identity: |" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
cat /home/ec2-user/environment/flux | sed 's/^/      /' >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml

echo "    identity.pub: |" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
cat /home/ec2-user/environment/flux.pub | sed 's/^/      /' >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml

# Append known hosts
echo "    known_hosts: |" >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml
cat /home/ec2-user/environment/temp_known_hosts | sed 's/^/      /' >> ${TERRAFORM_CLUSTER_FOLDER}/values.yaml

cd $TERRAFORM_CLUSTER_FOLDER

export TENANT_ONBOARDING_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/tenant-onboarding"

# Changing Workflow Call manifest
sed -i "s|{REPO_URL}|${CLONE_URL_CODECOMMIT_USER}|g" "${TENANT_ONBOARDING_FOLDER}/create-new-tenant.yaml"
sed -i "s|{AWS_REGION}|${AWS_REGION}|g" "${TENANT_ONBOARDING_FOLDER}/create-new-tenant.yaml"
sed -i "s|{CODECOMMIT_USER}|${CODECOMMIT_USER_ID}|g" "${TENANT_ONBOARDING_FOLDER}/create-new-tenant.yaml"

echo "Applying Terraform to deploy flux"

terraform init && terraform apply -var "git_url=${CLONE_URL_CODECOMMIT_USER}" -var "aws_region=${AWS_REGION}" -auto-approve

echo "Final setup commit"

cd /home/ec2-user/environment/eks-saas-gitops-aws
git add .
git commit -m 'Flux system sync including private key'
git push origin main

# Defining EKS context
aws eks --region $AWS_REGION update-kubeconfig --name eks-saas-gitops

echo "Configuring kubectl access for ec2-user"
# Giving access to EC2 user
mkdir -p /home/ec2-user/.kube && cp /root/.kube/config /home/ec2-user/.kube/ && chown -R ec2-user:ec2-user /home/ec2-user/.kube/config

sleep 120

aws eks --region $AWS_REGION update-kubeconfig --name eks-saas-gitops

echo "Verifying if any installation needs to be reconciled"
helm uninstall kubecost -nkubecost --kubeconfig /root/.kube/config
flux reconcile helmrelease kubecost -nflux-system --kubeconfig /root/.kube/config

helm uninstall karpenter -nkarpenter --kubeconfig /root/.kube/config
flux reconcile helmrelease karpenter -nflux-system --kubeconfig /root/.kube/config

echo "Changing permissions for ec2-user"
chown -R ec2-user:ec2-user /home/ec2-user/environment/

# Creating secret for Argo Workflows
echo "Creating Argo Workflows secret ssh"

kubectl create secret generic github-ssh-key --from-file=ssh-privatekey=/home/ec2-user/environment/flux --from-literal=ssh-privatekey.mode=0600 -nargo-workflows --kubeconfig /root/.kube/config