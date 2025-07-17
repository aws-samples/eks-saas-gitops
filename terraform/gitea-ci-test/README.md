# Gitea CI Test Environment

This Terraform configuration sets up a minimal environment for testing Gitea with Actions enabled and ECR repositories for CI/CD. It's designed to be a standalone test environment that can be deployed separately from the main infrastructure.

## Components

- **VPC and Networking**: A simple VPC with a public subnet, internet gateway, and route table
- **Gitea Server**: EC2 instance running Gitea with Actions enabled
- **Gitea Actions Runner**: Automatically configured runner for CI/CD
- **ECR Repositories**: Container repositories for each microservice

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- Access to the internet from your deployment machine

## Deployment Instructions

1. Review and customize the variables in `variables.tf` if needed
2. Initialize Terraform:
   ```
   terraform init
   ```
3. Apply the configuration:
   ```
   terraform apply
   ```
4. After deployment, note the Gitea URL from the outputs:
   ```
   terraform output gitea_url
   ```

## Testing the CI/CD Pipeline

### Automatic Setup

A setup script is provided to automatically create repositories, push code, and configure the necessary variables:

```bash
# Make the script executable if needed
chmod +x setup-repos.sh

# Run the setup script
./setup-repos.sh \
  --gitea-url "http://gitea-public-ip:3000" \
  --gitea-password "your-admin-password" \
  --aws-region "us-east-1"
```

This script will:
1. Create repositories for each microservice
2. Push the initial code to these repositories
3. Set up the necessary repository variables for the workflows

### Manual Setup

If you prefer to set up manually:

1. Access the Gitea server using the URL from the outputs
2. Log in with the admin credentials (default username: `admin`, password from `var.gitea_admin_password`)
3. Create repositories for each microservice (producer, consumer, payments)
4. Push the microservice code to these repositories, including the `.gitea/workflows/build-and-push.yml` files
5. Set up repository variables for each repository:
   - `AWS_REGION`: The AWS region where your ECR repository is located
   - `REPOSITORY_URI`: The URI of your ECR repository (available in the Terraform outputs)
6. Make a change and push to trigger the workflow

## Cleanup

To destroy the test environment:
```
terraform destroy
```

## Security Notes

- The default admin password is set in `variables.tf` and should be changed for any non-temporary deployment
- By default, the Gitea server is accessible from anywhere; set `allowed_ip` to restrict access
- The EC2 instance has permissions to push to ECR; review the IAM policies if needed
