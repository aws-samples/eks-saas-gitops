# How to Provision This Stack

This comprehensive guide is designed to assist you in efficiently setting up and provisioning the necessary stack. By adhering to the outlined steps and recommendations, you'll facilitate a seamless setup experience.

## Prerequisites

Before initiating the setup process, please ensure the following tools are installed and configured on your system:

- **Terraform**: Automate infrastructure management with ease. [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Kubectl**: Interact with your Kubernetes cluster. [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Flux CLI**: Manage GitOps for your cluster. [Installation Guide](https://fluxcd.io/flux/installation/)
- **AWS CLI**: Control AWS services directly from your terminal. [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS Credentials**: Essential for authenticating AWS CLI and Terraform commands. [Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- **Key Pairs (Private and Public)**: Secure your connections with SSH keys. [SSH Key Generation Guide](https://en.wikibooks.org/wiki/Cryptography/Generate_a_keypair_using_OpenSSL)

## Installation Steps

### Step 1: Configure SSH Known Hosts
To securely clone repositories, you must add AWS CodeCommit to your `known_hosts`. Replace `AWS_REGION` with your target AWS region:

```bash
export AWS_REGION="us-west-2"
ssh-keyscan "git-codecommit.$AWS_REGION.amazonaws.com" >> ~/.ssh/known_hosts
```

### Step 2: Run the Installation Script
Our `install.sh` script streamlines the provisioning process. Specify paths in the following order: public SSH key, private SSH key, the clone directory, and `known_hosts`.

```bash
./install.sh ~/.ssh/id_rsa.pub ~/.ssh/id_rsa path/to/my-directory ~/.ssh/known_hosts
```

> **Important**: Replace placeholder values with your actual file paths. The `clone_directory` is a destination that you want to store the sample applications source code in your local machine. The code created in this directory will be used to create the git repositories on AWS CodeCommit.

### Step 3: Accessing the Environment

Post-installation, use the `configure_kubectl` Terraform output to connect to your Kubernetes cluster:

```bash
aws eks --region us-west-2 update-kubeconfig --name eks-saas-gitops
```

### Step 4: Create git ssh keys in EKS for Argo Workflows

Argo Workflows needs access to the git repository. Create a secret to store the private keys that Argo will use to clone and push changes to git during workflows.

```bash
kubectl create secret generic github-ssh-key --from-file=ssh-privatekey= ~/.ssh/id_rsa --from-literal=ssh-privatekey.mode=0600 -nargo-workflows --kubeconfig ~/.kube/config
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

To link your GitHub Gists directly in your README file for easy access and reference, you can incorporate them as follows. I'll guide you on how to add a link to your Gist under the appropriate section of your README. Here's how you might format it:

### How to Test the Architecture

For a detailed guide on deploying and testing the architecture, including the deployment of tenants, setting up SQS queues, and managing Kubernetes deployments, please refer to the following Gist:

[Testing Guide](https://gist.github.com/lusoal/4de3dea19ded8f71f12dfcd82111ee57)

This Gist includes step-by-step instructions and the necessary scripts to perform initial setup, deployments, and demonstrations of the system's capabilities.

## Conclusion

Following this guide will help you establish a robust environment tailored to your requirements. Should you encounter any issues, refer to the troubleshooting section for solutions or consider revisiting the prerequisites to ensure all components are correctly installed and configured.
