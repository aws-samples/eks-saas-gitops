# EKS SaaS GitOps Workshop Source Repository

Welcome to the source repository for the **EKS SaaS GitOps Workshop**. This repository serves as a template to generate multiple other repositories, enabling a hands-on GitOps experience using Amazon EKS. It provides you with all the necessary patterns, configurations, and scripts to deploy a scalable SaaS application.

## Repository Overview

This template repository is the foundation for creating individual repositories for the components of your SaaS architecture, as shown in the diagram below. These repositories include configurations for various microservices like Producer, Consumer, and Payments, each tailored to demonstrate best practices in a GitOps workflow.

![Repository Structure Diagram](./static/github-repo-template.png)

This repository is organized to facilitate a hands-on learning experience, structured as follows:

- **`/gitops`**: Contains GitOps configurations and templates for setting up the application plane, clusters, control plane, and infrastructure necessary for the SaaS architecture.
- **`/helpers`**: Includes CloudFormation templates to assist in setting up the required AWS resources. (Only used if want to deploy Cloud9 and run this architecture all in AWS)
- **`/helm-charts`**: Houses Helm chart definitions for deploying tenant-specific resources within the Kubernetes cluster and shared services resources.
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