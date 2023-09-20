# GitOps SaaS for Multi-Tenancy

This repository offers a sample pattern to manage multi-tenancy in a Kubernetes cluster using GitOps with Flux. The provided CloudFormation template automates the deployment of necessary AWS resources and sets up an environment ready for GitOps practices.

## 🛠 Pre-requisites

- **AWS CLI**: Ensure you have the AWS CLI installed and configured with the necessary permissions.
- **Git**: Make sure Git is installed for cloning this repository.

## 🚀 Deployment Steps

### Step 1: Clone the Repository

Clone this repository to your local machine to get the CloudFormation template and other helper scripts.

```bash
git clone <repository_url>
```

### Step 2: Navigate to the Directory

Open your terminal and navigate to the directory where your CloudFormation template is saved.

```bash
cd path/to/repo
```

### Step 3: Create the CloudFormation Stack

Execute the following AWS CLI command to deploy the stack. Make sure to replace placeholders accordingly.

```bash
aws cloudformation create-stack \
--stack-name YourStackName \
--template-body file://helpers/cloudformation.yaml \
--parameters ParameterKey=C9EnvType,ParameterValue=YOUR_CHOICE_HERE \
--capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"
```
- `YOUR_CHOICE_HERE`: Use either `self` or `event-engine` based on your specific installation requirement.

### Step 4: Verify Stack Creation

Once the command is executed, navigate to the [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation/) to monitor the stack's status.

## ⏳ Wait for Environment Setup

Post stack deployment, it might take a few minutes for the environment to become operational. This is mainly because the Terraform setup includes provisioning a Cloud9 instance and running the [`install.sh`](./install.sh) script. To check the progress, you can visit the [SSM Run Command Console](https://console.aws.amazon.com/systems-manager/run-command/executing-commands).

> **Note**: Make sure you're operating in the region where the stack was deployed.

## 🖥 Accessing Cloud9

To access your newly created Cloud9 environment:

1. Go to the [AWS Cloud9 Console](https://console.aws.amazon.com/cloud9/).
2. Find your Cloud9 instance listed under "Your environments."
3. Click "Open IDE" to start working in your Cloud9 environment.
