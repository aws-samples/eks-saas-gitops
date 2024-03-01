# How to Provision This Stack

This step-by-step guide will assist you in setting up and provisioning the required stack, with detailed information on prerequisites and the installation process. By following this guide, you'll ensure a smoother setup experience.

## Prerequisites
Before starting, ensure you have the following tools installed on your system:
- **Terraform**: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Kubectl**: [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Flux**: [Installation Guide](https://fluxcd.io/docs/installation/)
- **AWS CLI**: [Installation Guide](https://aws.amazon.com/cli/)
- **AWS Credentials Configured**: [Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- **Key Pairs (Private and Public)**: [SSH Key Generation Guide](https://en.wikibooks.org/wiki/Cryptography/Generate_a_keypair_using_OpenSSL)

## Installation Steps

### Step 1: Configure SSH Known Hosts
Before installing the stack, you need to create the `known_hosts` file based on the AWS Region where you're provisioning the environment. Execute the following command, replacing `AWS_REGION` with your specific region:

```bash
export AWS_REGION="us-west-2"
ssh-keyscan "git-codecommit.$AWS_REGION.amazonaws.com" >> ~/.ssh/known_hosts
```

### Step 2: Run the Installation Script
We've prepared an `install.sh` script to simplify the provisioning process. You'll need to pass your `public_key_file_path`, `private_key_file_path`, `clone_directory`, and `known_hosts`. Follow the instructions in the prerequisites section on how to generate these.

Execute the script with your specific values as shown below:

```bash
./install.sh ~/.ssh/id_rsa.pub ~/.ssh/id_rsa path/to/my-directory ~/.ssh/known_hosts
```

> **Note:** Make sure to replace the values with your own before executing the script. The `clone_directory` is where the generated files will be hosted.

### Ensuring Smooth Installation
- Verify that all prerequisites are correctly installed and configured before proceeding.
- Double-check the AWS region set by `export AWS_REGION` command; it must match the region where you intend to provision the resources.
- Ensure your AWS credentials are correctly configured to avoid any permissions issues during the provisioning process.