# How to Provision This Stack

This comprehensive guide is designed to assist you in efficiently setting up and provisioning the necessary stack. By adhering to the outlined steps and recommendations, you'll facilitate a seamless setup experience.

## Prerequisites

Before initiating the setup process, please ensure the following tools are installed and configured on your system:

- **Terraform**: Automate infrastructure management with ease. [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Kubectl**: Interact with your Kubernetes cluster. [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Flux CLI**: Manage GitOps for your cluster. [Installation Guide](https://fluxcd.io/flux/installation/)
- **AWS CLI**: Control AWS services directly from your terminal. [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS Credentials**: Essential for authenticating AWS CLI and Terraform commands. [Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

## Installation Steps

### Step 1: Configure SSH Known Hosts
To securely clone repositories, you must add AWS CodeCommit to your `known_hosts`. Replace `AWS_REGION` with your target AWS region:

```bash
export AWS_REGION=""
ssh-keyscan "git-codecommit.$AWS_REGION.amazonaws.com" >> ~/.ssh/known_hosts
```

### Step 1: Run the Installation Script
The `install.sh` script will deploy the AWS and Gitea infrastructure.

```bash
cd terraform &&  sh install.sh
```

### Step 2: Accessing the Environment

Post-installation, use the `configure_kubectl` Terraform output to connect to your Kubernetes cluster:

```bash
aws eks --region $AWS_REGION update-kubeconfig --name eks-saas-gitops
```

## Ensuring Smooth Installation

To guarantee a smooth installation:

- Confirm the installation and configuration of all prerequisites.
- Verify the AWS region in `echo $AWS_REGION` matches your intended provision region.
- Ensure AWS credentials are correctly set to prevent any access or permission issues.

## Troubleshooting with quick_fix_flux.sh

Occasionally, you might encounter errors due to race conditions during the provisioning process, such as failed Helm releases. Typical errors include:

- Helm install failures due to webhook service unavailability.
- Artifacts not being stored correctly for certain Helm releases.

Should these or similar errors arise, run the `quick_fix_flux.sh` script to resolve them swiftly:

```bash
./quick_fix_flux.sh
```

This script dynamically identifies and deletes failed Helm releases, then reconciles your `flux-system` source to reattempt their installation. Running `quick_fix_flux.sh` ensures your environment stabilizes by rectifying transient errors that commonly occur due to race conditions during initial setup.

### How to Test the Architecture

For a detailed guide on deploying and testing the architecture, including the deployment of tenants, setting up SQS queues, and managing Kubernetes deployments, please refer to the following Workshop:

[Building SaaS applications on Amazon EKS using GitOps](https://catalog.workshops.aws/eks-saas-gitops).
