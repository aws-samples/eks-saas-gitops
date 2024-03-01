# EKS SaaS GitOps Workshop Source Repository

Welcome to the source repository for the **EKS SaaS GitOps Workshop**. This repository is designed to support the AWS Workshop, providing you with all necessary patterns, configurations, and scripts to deploy a SaaS application using Amazon EKS and GitOps methodologies. Through this workshop, you'll learn how to leverage Kubernetes, FluxCD, and Terraform to automate the provisioning and management of a scalable SaaS platform.

## Repository Overview

This repository is organized to facilitate a hands-on learning experience, structured as follows:

- **`/gitops`**: Contains GitOps configurations and templates for setting up the application plane, clusters, control plane, and infrastructure necessary for the SaaS architecture.
- **`/helpers`**: Includes CloudFormation templates to assist in setting up the required AWS resources.
- **`/tenant-chart`**: Houses Helm chart definitions for deploying tenant-specific resources within the Kubernetes cluster.
- **`/tenant-microservices`**: Contains the source code and Dockerfiles for the sample microservices used in the workshop (consumer, payments, producer).
- **`/terraform`**: Features Terraform modules and scripts for provisioning the AWS infrastructure and Kubernetes resources. Detailed setup instructions are provided within this folder's README.md.
- **`/workflow-scripts`**: Provides scripts to automate the workflow for tenant onboarding and application deployment within the GitOps framework.

## Getting Started

Begin your journey to deploying a SaaS architecture on Amazon EKS by closely following the detailed instructions provided in the [/terraform folder's README.](terraform/README.md) This guide is your starting point for setting up the AWS environment, configuring your Kubernetes cluster, and applying GitOps principles for efficient resource management.

## Contributing

Your contributions are welcome! If you'd like to improve the workshop or suggest changes, please feel free to submit issues or pull requests.

## Code of Conduct & Contributing

We value your input and contributions! Please review our [Code of Conduct](CODE_OF_CONDUCT.md) and [Contributing Guidelines](CONTRIBUTING.md) for how to participate in making this project better.

## License

This project is licensed under the terms of the [MIT license](LICENSE).