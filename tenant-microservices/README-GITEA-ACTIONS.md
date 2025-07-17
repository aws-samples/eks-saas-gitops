# Setting Up Gitea Actions for CI/CD

This project uses Gitea Actions for CI/CD to build and push Docker images to Amazon ECR. This README explains how to set up the necessary configuration for the workflows to work correctly.

## Prerequisites

- Gitea server with Actions enabled (configured in the Gitea module's userdata.sh)
- Gitea act_runner configured and running (automatically set up in the userdata.sh)
- AWS ECR repositories created for each microservice

## How Gitea Actions Works

Gitea Actions is a CI/CD feature built into Gitea that is compatible with GitHub Actions workflows. It allows you to define workflows in YAML files that are triggered by events like pushes or pull requests.

The key components are:

1. **Workflows**: YAML files in the `.gitea/workflows/` directory that define the CI/CD pipeline
2. **Runners**: Servers that execute the workflows (in our case, the Gitea server itself)
3. **Actions**: Reusable units of code that can be used in workflows (we use standard GitHub Actions)

## Repository Setup

For each microservice repository (producer, consumer, payments), you need to set up the following repository variables:

1. Navigate to your repository in Gitea
2. Go to Settings > Actions > Variables
3. Add the following variables:

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `AWS_REGION` | The AWS region where your ECR repository is located | `us-east-1` |
| `REPOSITORY_URI` | The URI of your ECR repository | `123456789012.dkr.ecr.us-east-1.amazonaws.com/producer` |

## Workflow Files

Each microservice repository contains a workflow file at `.gitea/workflows/build-and-push.yml` that defines the CI/CD pipeline. The workflow:

1. Checks out the code
2. Configures AWS credentials (using the EC2 instance role)
3. Logs in to Amazon ECR
4. Builds the Docker image
5. Tags the image with a timestamp and "latest"
6. Pushes the image to ECR

## How It Works

The workflow is triggered on:
- Push to the `main` branch
- Pull requests to the `main` branch

The Gitea runner executes the workflow and uses the AWS credentials from the EC2 instance role to authenticate with AWS services. This means the EC2 instance running the Gitea server must have the appropriate IAM permissions to push to ECR.

## Troubleshooting

If you encounter issues with the workflow:

1. Check that the Gitea Actions runner is properly registered and running
2. Verify that the repository variables are correctly set
3. Ensure the EC2 instance has the necessary IAM permissions to push to ECR
4. Check the workflow logs in the Gitea UI for specific error messages

## Migration from CodeBuild/CodePipeline

This setup replaces the previous CodeBuild/CodePipeline configuration. The main differences are:

- CI/CD is now managed through Gitea Actions instead of AWS services
- The workflow configuration is stored in the repository instead of AWS
- Authentication with AWS is handled through the EC2 instance role
