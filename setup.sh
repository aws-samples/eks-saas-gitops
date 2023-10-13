#!/bin/bash
set -e
trap 'catch_error $? $LINENO' ERR

catch_error() {
    #send response back to cloudformation
    export JSON_DATA="{
        \"Status\" : \"FAILED\",
        \"Reason\" : \"Error $1 occurred on $2\",
        \"StackId\" : \"$EVENT_STACK_ID\",
        \"PhysicalResourceId\" : \"$PHYSICAL_RESOURCE_ID\",
        \"RequestId\" : \"$EVENT_REQUEST_ID\",
        \"LogicalResourceId\" : \"$EVENT_LOGICAL_RESOURCE_ID\"
    }"
    curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"
}

# # Set system locale
# echo 'LANG=en_US.utf-8' >> /etc/environment
# echo 'LC_ALL=en_US.UTF-8' >> /etc/environment

# # Source the user's bashrc
# source /home/ec2-user/.bashrc

# # Update system packages and install dependencies
# echo '=== UPDATE system packages and INSTALL dependencies ==='
# yum update -y
# yum install -y vim git jq bash-completion moreutils gettext yum-utils perl-Digest-SHA tree

# # Enable Amazon Extras EPEL Repository and install Git LFS
# echo '=== ENABLE Amazon Extras EPEL Repository and INSTALL Git LFS ==='
# yum install -y amazon-linux-extras
# amazon-linux-extras install epel -y
# yum install -y git-lfs

# # Install AWS CLI v2
# echo '=== INSTALL AWS CLI v2 ==='
# curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'
# unzip awscliv2.zip -d /tmp
# /tmp/aws/install --update
# rm -rf /tmp/aws awscliv2.zip

# # Install Kubernetes CLI (kubectl)
# echo '=== INSTALL Kubernetes CLI ==='
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# chmod +x kubectl
# mv kubectl /usr/local/bin/
# /usr/local/bin/kubectl completion bash > /etc/bash_completion.d/kubectl

# # Install Helm CLI
# echo '=== INSTALL Helm CLI ==='
# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# /usr/local/bin/helm completion bash > /etc/bash_completion.d/helm

# # Install Eksctl CLI
# echo '=== INSTALL Eksctl CLI ==='
# curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
# mv /tmp/eksctl /usr/local/bin
# /usr/local/bin/eksctl completion bash > /etc/bash_completion.d/eksctl

# # Install Flux CLI
# echo '=== INSTALL Flux CLI ==='
# curl --silent --location "https://github.com/fluxcd/flux2/releases/download/v0.41.2/flux_0.41.2_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
# mv /tmp/flux /usr/local/bin
# /usr/local/bin/flux completion bash > /etc/bash_completion.d/flux

# # Install PLUTO
# echo '=== INSTALL PLUTO ==='
# curl --silent --location "https://github.com/FairwindsOps/pluto/releases/download/v5.16.1/pluto_5.16.1_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
# mv /tmp/pluto /usr/local/bin

# # Install KUBENT
# echo '=== INSTALL KUBENT ==='
# curl --silent --location "https://github.com/doitintl/kube-no-trouble/releases/download/0.7.0/kubent-0.7.0-$(uname -s)-amd64.tar.gz" | tar xz -C /tmp
# mv /tmp/kubent /usr/local/bin

# # Install kubectl convert plugin
# echo '=== INSTALL kubectl convert plugin ==='
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl-convert"
# install -o root -g root -m 0755 kubectl-convert /usr/local/bin/kubectl-convert

# # Install Terraform CLI
# echo '=== INSTALL Terraform CLI ==='
# yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
# yum -y install terraform

# aws cloud9 update-environment --environment-id "$C9_PID" --managed-credentials-action DISABLE

# # Provision Terraform
# echo '====== Provision Terraform ======'
# git clone https://github.com/somensi-aws/eks-saas-gitops.git /home/ec2-user/environment/eks-saas-gitops
# chmod +x /home/ec2-user/environment/eks-saas-gitops/install.sh
# /home/ec2-user/environment/install.sh

# Reboot the system
#shutdown -r +1

#send response back to cloudformation
export JSON_DATA="{
    \"Status\" : \"SUCCESS\",
    \"Reason\" : \"install completed\",
    \"StackId\" : \"$EVENT_STACK_ID\",
    \"PhysicalResourceId\" : \"$PHYSICAL_RESOURCE_ID\",
    \"RequestId\" : \"$EVENT_REQUEST_ID\",
    \"LogicalResourceId\" : \"$EVENT_LOGICAL_RESOURCE_ID\"
}"

curl -X PUT --data-binary "$JSON_DATA" "$EVENT_RESPONSE_URL"