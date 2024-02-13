#!/bin/bash
set -e
trap 'catch_error $? $LINENO' ERR

catch_error() {
     #get cfn parameter from ssm
     CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 
     
     #set variables
     STATUS="FAILED"
     EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
     EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
     EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
     EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

     JSON_DATA='{
          "Status": "'"$STATUS"'",
          "Reason": "Error '"$1"' occurred on '"$2"'",
          "StackId": "'"$EVENT_STACK_ID"'",
          "PhysicalResourceId": "Terraform",
          "RequestId": "'"$EVENT_REQUEST_ID"'",
          "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
     }'

     # Send the JSON data using curl
     curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"          
}

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
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
     -target=module.argo_events_eks_role \
     -target=random_uuid.uuid \
     -target=aws_s3_bucket.argo_artifacts \
     -target=aws_sqs_queue.argoworkflows_queue \
     -target=module.lb_controller_irsa \
     -target=aws_ecr_repository.tenant_helm_chart \
     -target=aws_ecr_repository.argoworkflow_container \
     -target=aws_ecr_repository.consumer_container \
     -target=aws_ecr_repository.producer_container \
     -target=aws_ecr_repository.payments_container \
     -target=module.codecommit_flux \
     -target=module.codecommit_producer \
     -target=module.codecommit_consumer \
     -target=module.codecommit_payments \
     -target=aws_iam_user.codecommit_user \
     -target=aws_iam_user_policy_attachment.codecommit_user_attach \
     -target=module.ebs_csi_irsa_role \
     -target=aws_s3_bucket.tenant_terraform_state_bucket \
     -target=module.tf_controller_irsa_role --auto-approve

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
          "argo_events_irsa"
          "argo_workflows_onboarding_sqs_url"
          "argo_workflows_deployment_sqs_url"
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
          "ecr_payments_container" 
          "karpenter_instance_profile" 
          "karpenter_irsa" 
          "lb_controller_irsa"
          "tenant_terraform_state_bucket_name"
          "aws_codecommit_producer_clone_url_http"
          "aws_codecommit_producer_clone_url_ssh"
          "aws_codecommit_consumer_clone_url_http"
          "aws_codecommit_consumer_clone_url_ssh"
          "aws_codecommit_payments_clone_url_ssh"
          "aws_codecommit_payments_clone_url_http"
          "tf_controller_irsa_role_arn")

for output in "${outputs[@]}"; do
     value=$(terraform output -raw "$output")
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
producer_clone_url="ssh://${ssh_public_key_id}@$(echo ${AWS_CODECOMMIT_PRODUCER_CLONE_URL_SSH} | cut -d'/' -f3-)"
consumer_clone_url="ssh://${ssh_public_key_id}@$(echo ${AWS_CODECOMMIT_CONSUMER_CLONE_URL_SSH} | cut -d'/' -f3-)"
payments_clone_url="ssh://${ssh_public_key_id}@$(echo ${AWS_CODECOMMIT_PAYMENTS_CLONE_URL_SSH} | cut -d'/' -f3-)"

export CODECOMMIT_USER_ID=$(aws iam list-ssh-public-keys --user-name codecommit-user | jq -r '.SSHPublicKeys[0].SSHPublicKeyId')
echo "export CODECOMMIT_USER_ID=${CODECOMMIT_USER_ID}" >> /home/ec2-user/.bashrc
echo "export CODECOMMIT_USER_ID=${CODECOMMIT_USER_ID}" >> /root/.bashrc

export CLONE_URL_CODECOMMIT_USER=${modified_clone_url}
echo "export CLONE_URL_CODECOMMIT_USER=${CLONE_URL_CODECOMMIT_USER}" >> /home/ec2-user/.bashrc
echo "export CLONE_URL_CODECOMMIT_USER=${CLONE_URL_CODECOMMIT_USER}" >> /root/.bashrc

export CLONE_URL_CODECOMMIT_USER_PRODUCER=${producer_clone_url}
echo "export CLONE_URL_CODECOMMIT_USER_PRODUCER=${CLONE_URL_CODECOMMIT_USER_PRODUCER}" >> /home/ec2-user/.bashrc
echo "export CLONE_URL_CODECOMMIT_USER_PRODUCER=${CLONE_URL_CODECOMMIT_USER_PRODUCER}" >> /root/.bashrc

export CLONE_URL_CODECOMMIT_USER_CONSUMER=${consumer_clone_url}
echo "export CLONE_URL_CODECOMMIT_USER_CONSUMER=${CLONE_URL_CODECOMMIT_USER_CONSUMER}" >> /home/ec2-user/.bashrc
echo "export CLONE_URL_CODECOMMIT_USER_CONSUMER=${CLONE_URL_CODECOMMIT_USER_CONSUMER}" >> /root/.bashrc

export CLONE_URL_CODECOMMIT_USER_PAYMENTS=${payments_clone_url}
echo "export CLONE_URL_CODECOMMIT_USER_PAYMENTS=${CLONE_URL_CODECOMMIT_USER_PAYMENTS}" >> /home/ec2-user/.bashrc
echo "export CLONE_URL_CODECOMMIT_USER_PAYMENTS=${CLONE_URL_CODECOMMIT_USER_PAYMENTS}" >> /root/.bashrc

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
git clone $CLONE_URL_CODECOMMIT_USER_PRODUCER
git clone $CLONE_URL_CODECOMMIT_USER_CONSUMER
git clone $CLONE_URL_CODECOMMIT_USER_PAYMENTS

# Flux repository copy from public repo to CodeCommit
cp -r /home/ec2-user/environment/eks-saas-gitops/* /home/ec2-user/environment/eks-saas-gitops-aws
cp /home/ec2-user/environment/eks-saas-gitops/.gitignore /home/ec2-user/environment/eks-saas-gitops-aws/.gitignore

# Producer microsservice copy repository
cp -r /home/ec2-user/environment/eks-saas-gitops/tenant-microservices/producer/* /home/ec2-user/environment/producer
cp /home/ec2-user/environment/eks-saas-gitops/.gitignore /home/ec2-user/environment/producer/.gitignore
cd /home/ec2-user/environment/producer/ && git checkout -b main && git add . && git commit -am "Added producer MS and configs" && git push origin main

# Consumer microsservice copy repository
cp -r /home/ec2-user/environment/eks-saas-gitops/tenant-microservices/consumer/* /home/ec2-user/environment/consumer
cp /home/ec2-user/environment/eks-saas-gitops/.gitignore /home/ec2-user/environment/consumer/.gitignore
cd /home/ec2-user/environment/consumer/ && git checkout -b main && git add . && git commit -am "Added consumer MS and configs" && git push origin main

# Payments microsservice copy repository
cp -r /home/ec2-user/environment/eks-saas-gitops/tenant-microservices/payments/* /home/ec2-user/environment/payments
cp /home/ec2-user/environment/eks-saas-gitops/.gitignore /home/ec2-user/environment/payments/.gitignore
cd /home/ec2-user/environment/payments/ && git checkout -b main && git add . && git commit -am "Added payments MS and configs" && git push origin main

# Removing GitHub repository
rm -rf /home/ec2-user/environment/eks-saas-gitops
cd /home/ec2-user/environment

echo "Create pool-1 application infra"

# Creating pool-1 application infra
export APPLICATION_PLANE_INFRA_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/production/environments"
export APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/terraform/application-plane/templates"

sed -e "s|{AWS_REGION}|${AWS_REGION}|g" "${APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER}/providers.tf.template" > ${APPLICATION_PLANE_INFRA_FOLDER}/providers.tf
sed -i "s|{TERRAFORM_STATE_BUCKET}|${TENANT_TERRAFORM_STATE_BUCKET_NAME}|g" "${APPLICATION_PLANE_INFRA_FOLDER}/providers.tf"

sed -i "s|__MODULE_SOURCE__|${AWS_CODECOMMIT_CLONE_URL_SSH}|g" "${APPLICATION_PLANE_INFRA_FOLDER}/pooled-1.tf"
sed -i "s|__MODULE_SOURCE__|${AWS_CODECOMMIT_CLONE_URL_SSH}|g" "${APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER}/hybrid-template.tf.template"
sed -i "s|__MODULE_SOURCE__|${AWS_CODECOMMIT_CLONE_URL_SSH}|g" "${APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER}/pool-template.tf.template"
sed -i "s|__MODULE_SOURCE__|${AWS_CODECOMMIT_CLONE_URL_SSH}|g" "${APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER}/silo-template.tf.template"
sed -i "s|__MODULE_SOURCE__|${AWS_CODECOMMIT_CLONE_URL_SSH}|g" "${APPLICATION_PLANE_INFRA_TEMPLATE_FOLDER}/pool-env-template.tf.template"

echo "Changing template files to terraform output values"

# Changing template files to use the new values
export GITOPS_FOLDER="/home/ec2-user/environment/eks-saas-gitops-aws/gitops"
export ONBOARDING_FOLER="/home/ec2-user/environment/eks-saas-gitops-aws/workflow-scripts"
export TENANT_CHART_FOLER="/home/ec2-user/environment/eks-saas-gitops-aws/tenant-chart"

sed -e "s|{TENANT_CHART_HELM_REPO}|$(echo "${ECR_HELM_CHART_URL}" | sed 's|\(.*\)/.*|\1|')|g" "${GITOPS_FOLDER}/infrastructure/base/sources/tenant-chart-helm.yaml.template" > ${GITOPS_FOLDER}/infrastructure/base/sources/tenant-chart-helm.yaml
sed -e "s|{KARPENTER_CONTROLLER_IRSA}|${KARPENTER_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml.template" > ${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml
sed -i "s|{EKS_CLUSTER_ENDPOINT}|${CLUSTER_ENDPOINT}|g" "${GITOPS_FOLDER}/infrastructure/production/02-karpenter.yaml"
sed -e "s|{ARGO_WORKFLOW_IRSA}|${ARGO_WORKFLOWS_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml.template" > "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml"
sed -e "s|{ARGO_EVENTS_IRSA}|${ARGO_EVENTS_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/06-argo-events.yaml.template" > "${GITOPS_FOLDER}/infrastructure/production/06-argo-events.yaml"
sed -i "s|{ARGO_WORKFLOW_BUCKET}|${ARGO_WORKFLOWS_BUCKET_NAME}|g" "${GITOPS_FOLDER}/infrastructure/production/03-argo-workflows.yaml"
sed -e "s|{LB_CONTROLLER_IRSA}|${LB_CONTROLLER_IRSA}|g" "${GITOPS_FOLDER}/infrastructure/production/04-lb-controller.yaml.template" > ${GITOPS_FOLDER}/infrastructure/production/04-lb-controller.yaml
sed -i "s|{ARGO_WORKFLOW_CONTAINER}|${ECR_ARGOWORKFLOW_CONTAINER}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-onboarding-workflow-template.yaml"
sed -i "s|{REPO_URL}|${CLONE_URL_CODECOMMIT_USER}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-onboarding-sensor.yaml"
sed -i "s|{AWS_REGION}|${AWS_REGION}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-onboarding-sensor.yaml"
sed -i "s|{CODECOMMIT_USER_ID}|${CODECOMMIT_USER_ID}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-onboarding-sensor.yaml"

sed -i "s|{ARGO_WORKFLOW_CONTAINER}|${ECR_ARGOWORKFLOW_CONTAINER}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-deployment-workflow-template.yaml"
sed -i "s|{AWS_REGION}|${AWS_REGION}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-deployment-sensor.yaml"
sed -i "s|{REPO_URL}|${CLONE_URL_CODECOMMIT_USER}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-deployment-sensor.yaml"
sed -i "s|{CODECOMMIT_USER_ID}|${CODECOMMIT_USER_ID}|g" "${GITOPS_FOLDER}/control-plane/production/workflows/tenant-deployment-sensor.yaml"

sed -e "s|{CONSUMER_ECR}|${ECR_CONSUMER_CONTAINER}|g" "${TENANT_CHART_FOLER}/values.yaml.template" > ${TENANT_CHART_FOLER}/values.yaml
sed -i "s|{PRODUCER_ECR}|${ECR_PRODUCER_CONTAINER}|g" "${TENANT_CHART_FOLER}/values.yaml"

#TF Controller
sed -e "s|{TF_CONTROLLER_IRSA_ROLE_ARN}|${TF_CONTROLLER_IRSA_ROLE_ARN}|g" "${GITOPS_FOLDER}/infrastructure/production/07-tf-controller.yaml.template" > ${GITOPS_FOLDER}/infrastructure/production/07-tf-controller.yaml
sed -e "s|{CLONE_URL_CODECOMMIT_USER}|${CLONE_URL_CODECOMMIT_USER}|g" "${GITOPS_FOLDER}/infrastructure/base/sources/git-terraform.yaml.template" > ${GITOPS_FOLDER}/infrastructure/base/sources/git-terraform.yaml

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
docker build -t $ECR_PRODUCER_CONTAINER:0.1 tenant-microservices/producer
docker push $ECR_PRODUCER_CONTAINER:0.1

aws ecr get-login-password \
     --region $AWS_REGION | docker login \
     --username AWS \
     --password-stdin $ECR_CONSUMER_CONTAINER
docker build -t $ECR_CONSUMER_CONTAINER:0.1 tenant-microservices/consumer
docker push $ECR_CONSUMER_CONTAINER:0.1

aws ecr get-login-password \
     --region $AWS_REGION | docker login \
     --username AWS \
     --password-stdin $ECR_ARGOWORKFLOW_CONTAINER
docker build --build-arg aws_region=${AWS_REGION} -t $ECR_ARGOWORKFLOW_CONTAINER workflow-scripts
docker push $ECR_ARGOWORKFLOW_CONTAINER

# remove folders that are not needed on the GitOps repo
rm -rf /home/ec2-user/environment/eks-saas-gitops-aws/helpers
rm -rf /home/ec2-user/environment/eks-saas-gitops-aws/tenant-microservices

echo "First commit CodeCommit repository"

git checkout -b main
git add .
git commit -m 'Initial Setup, v0.0.1'
git push origin main

# Creating TAG in CodeCommit repository
LAST_COMMIT_ID=$(aws codecommit get-branch --repository-name eks-saas-gitops-aws --branch-name main | jq -r '.branch.commitId')
git tag v0.0.1 $LAST_COMMIT_ID
git push origin v0.0.1

# Applying after push for being able to reference tenants terraform as a module
cd $APPLICATION_PLANE_INFRA_FOLDER && terraform init && terraform apply -auto-approve
terraform output -json | jq ".\"pooled-1\".\"value\"" | yq e -P - | sed 's/^/      /' > /tmp/infra_outputs.yaml
sed -i '/infraValues:/r /tmp/infra_outputs.yaml' /home/ec2-user/environment/eks-saas-gitops-aws/gitops/application-plane/production/pooled-envs/pool-1.yaml

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

# echo "Verifying if any installation needs to be reconciled"
# helm uninstall kubecost -nkubecost --kubeconfig /root/.kube/config
# flux reconcile helmrelease kubecost -nflux-system --kubeconfig /root/.kube/config

# helm uninstall karpenter -nkarpenter --kubeconfig /root/.kube/config
# flux reconcile helmrelease karpenter -nflux-system --kubeconfig /root/.kube/config

# helm uninstall metrics-server -nkube-system --kubeconfig /root/.kube/config
# flux reconcile helmrelease metrics-server -nflux-system --kubeconfig /root/.kube/config

echo "Changing permissions for ec2-user"
chown -R ec2-user:ec2-user /home/ec2-user/environment/

# Creating secret for Argo Workflows
echo "Creating Argo Workflows secret ssh"

kubectl create secret generic github-ssh-key --from-file=ssh-privatekey=/home/ec2-user/environment/flux --from-literal=ssh-privatekey.mode=0600 -nargo-workflows --kubeconfig /root/.kube/config

#get cfn parameter from ssm
CFN_PARAMETER="$(aws ssm get-parameter --name "eks-saas-gitops-custom-resource-event" --query "Parameter.Value" --output text)" 

#set variables
STATUS="SUCCESS"
EVENT_STACK_ID=$(echo "$CFN_PARAMETER" | jq -r .StackId)
EVENT_REQUEST_ID=$(echo "$CFN_PARAMETER" | jq -r .RequestId)
EVENT_LOGICAL_RESOURCE_ID=$(echo "$CFN_PARAMETER" | jq -r .LogicalResourceId)
EVENT_RESPONSE_URL=$(echo "$CFN_PARAMETER" | jq -r .ResponseURL)

JSON_DATA='{
     "Status": "'"$STATUS"'",
     "Reason": "Terraform executed successfully from Cloud9",
     "StackId": "'"$EVENT_STACK_ID"'",
     "PhysicalResourceId": "Terraform",
     "RequestId": "'"$EVENT_REQUEST_ID"'",
     "LogicalResourceId": "'"$EVENT_LOGICAL_RESOURCE_ID"'"
}'

# Send the JSON data using curl
curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"
