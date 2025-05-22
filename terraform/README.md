# How to Provision This Stack

This comprehensive guide is designed to assist you in efficiently setting up and provisioning the necessary stack. By adhering to the outlined steps and recommendations, you'll facilitate a seamless setup experience.

## Deployment Options

### Option 1: Using the VSCode EC2 Instance (Recommended)

The easiest way to deploy this stack is by using our pre-configured VSCode EC2 instance:

1. **Deploy the VSCode EC2 Instance**:
   ```bash
   # Default deployment (allows access from anywhere - 0.0.0.0/0)
   aws cloudformation deploy --template-file helpers/vs-code-ec2.yaml --stack-name eks-saas-gitops-vscode --capabilities CAPABILITY_NAMED_IAM

   # Or, deploy with your specific IP address for enhanced security
   aws cloudformation deploy \
     --template-file helpers/vs-code-ec2.yaml \
     --stack-name eks-saas-gitops-vscode \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides AllowedIP=YOUR_IP_ADDRESS/32
   ```
   Note: Replace `YOUR_IP_ADDRESS` with your public IP address. You can find your public IP by using services like `curl ifconfig.me` or visiting whatismyip.com.

2. **Access the VSCode Environment**:
   - Once the CloudFormation stack is deployed, find the EC2 instance URL in the outputs
   - Open the URL in your browser to access the VSCode environment
   - The password for the VSCode server is stored in AWS Systems Manager Parameter Store under the parameter name 'coder-password'. This is linked in the CloudFormation output as well. 
   - The environment comes with all required tools pre-installed
   - Note: If you specified an IP address allowlist, only connections from that IP will be able to access the VSCode environment
   - The VSCode instance will automatically apply the Terraform infrastructure


### Option 2: Manual Deployment

> **IMPORTANT DISCLAIMER**: Manual deployment is not fully supported yet. The current architecture relies on VPC peering between the VSCode VPC and the main VPC containing both EKS and Gitea. The Terraform deployment will fail if the VSCode EC2 instance (deployed via CloudFormation) is not present, as it searches for specific VPC tags to establish the peering connection. We recommend using Option 1 for a reliable deployment experience.

## Prerequisites

Before initiating the setup process, please ensure the following tools are installed and configured on your system:

- **Terraform**: Automate infrastructure management with ease. [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Kubectl**: Interact with your Kubernetes cluster. [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Flux CLI**: Manage GitOps for your cluster. [Installation Guide](https://fluxcd.io/flux/installation/)
- **AWS CLI**: Control AWS services directly from your terminal. [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS Credentials**: Essential for authenticating AWS CLI and Terraform commands. [Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

## Installation Steps

### Step 1: Run the Installation Script
The `install.sh` script will deploy the AWS and Gitea infrastructure.

```bash
cd terraform && sh install.sh
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

## How to Test the Architecture

For a detailed guide on deploying and testing the architecture, including the deployment of tenants, setting up SQS queues, and managing Kubernetes deployments, please refer to the following Workshop:

[Building SaaS applications on Amazon EKS using GitOps](https://catalog.workshops.aws/eks-saas-gitops).
