# Amazon EKS Cluster and required infrastructure

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.22.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_argo_events_eks_role"></a> [argo\_events\_eks\_role](#module\_argo\_events\_eks\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_argo_workflows_eks_role"></a> [argo\_workflows\_eks\_role](#module\_argo\_workflows\_eks\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_codebuild_consumer_project"></a> [codebuild\_consumer\_project](#module\_codebuild\_consumer\_project) | ../../modules/codebuild | n/a |
| <a name="module_codebuild_producer_project"></a> [codebuild\_producer\_project](#module\_codebuild\_producer\_project) | ../../modules/codebuild | n/a |
| <a name="module_codecommit-consumer"></a> [codecommit-consumer](#module\_codecommit-consumer) | lgallard/codecommit/aws | 0.2.1 |
| <a name="module_codecommit-flux"></a> [codecommit-flux](#module\_codecommit-flux) | lgallard/codecommit/aws | 0.2.1 |
| <a name="module_codecommit-producer"></a> [codecommit-producer](#module\_codecommit-producer) | lgallard/codecommit/aws | 0.2.1 |
| <a name="module_codepipeline_consumer"></a> [codepipeline\_consumer](#module\_codepipeline\_consumer) | ../../modules/codepipeline | n/a |
| <a name="module_codepipeline_producer"></a> [codepipeline\_producer](#module\_codepipeline\_producer) | ../../modules/codepipeline | n/a |
| <a name="module_ebs_csi_irsa_role"></a> [ebs\_csi\_irsa\_role](#module\_ebs\_csi\_irsa\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 19.12 |
| <a name="module_flux_v2"></a> [flux\_v2](#module\_flux\_v2) | ../../modules/flux_cd | n/a |
| <a name="module_karpenter_irsa_role"></a> [karpenter\_irsa\_role](#module\_karpenter\_irsa\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_lb-controller-irsa"></a> [lb-controller-irsa](#module\_lb-controller-irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.argoworkflow_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository.consumer_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository.producer_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository.tenant_helm_chart](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_iam_instance_profile.karpenter_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.karpenter-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy_attachment.amazon_eks_cni_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.amazon_eks_ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.amazon_eks_worker_node_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.container_registry_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_policy_attachment.karpenter_policy_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.karpenter_node_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_user.codecommit-user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.codecommit-user-attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_s3_bucket.argo-artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.codeartifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.tenant-terraform-state-bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_sqs_queue.argoworkflows_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [random_uuid.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [random_uuid.uuid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argoworkflow_container_repo"></a> [argoworkflow\_container\_repo](#input\_argoworkflow\_container\_repo) | Repository for Argo Workflows container image | `string` | `"argoworkflow-container"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `null` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Amazon EKS Cluster version | `string` | `"1.27"` | no |
| <a name="input_consumer_container_repo"></a> [consumer\_container\_repo](#input\_consumer\_container\_repo) | Repository for Consumer container image | `string` | `"consumer-container"` | no |
| <a name="input_git_branch"></a> [git\_branch](#input\_git\_branch) | Branch of the Git repository | `string` | `"main"` | no |
| <a name="input_git_url"></a> [git\_url](#input\_git\_url) | URL for the Git repository | `string` | `""` | no |
| <a name="input_kustomization_path"></a> [kustomization\_path](#input\_kustomization\_path) | Path for Kustomization tool | `string` | `"gitops/clusters/production"` | no |
| <a name="input_name"></a> [name](#input\_name) | Stack name | `string` | `"eks-saas-gitops"` | no |
| <a name="input_producer_container_repo"></a> [producer\_container\_repo](#input\_producer\_container\_repo) | Repository for Producer container image | `string` | `"producer-container"` | no |
| <a name="input_tenant_helm_chart_repo"></a> [tenant\_helm\_chart\_repo](#input\_tenant\_helm\_chart\_repo) | Repository for Tenant Helm chart | `string` | `"gitops-saas/helm-tenant-chart"` | no |
| <a name="input_values_path"></a> [values\_path](#input\_values\_path) | Path for Helm chart values | `string` | `"./values.yaml"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Amazon VPC CIDR Block | `string` | `"10.35.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argo_events_irsa"></a> [argo\_events\_irsa](#output\_argo\_events\_irsa) | IAM Role for Argo Events Service Account |
| <a name="output_argo_workflows_bucket_name"></a> [argo\_workflows\_bucket\_name](#output\_argo\_workflows\_bucket\_name) | Amazon S3 bucket that Argo Workflows will store its artifacts |
| <a name="output_argo_workflows_irsa"></a> [argo\_workflows\_irsa](#output\_argo\_workflows\_irsa) | IAM Role for Argo Workflows Service Account |
| <a name="output_argo_workflows_sqs_url"></a> [argo\_workflows\_sqs\_url](#output\_argo\_workflows\_sqs\_url) | Amazon SQS queue URL |
| <a name="output_aws_codecommit_clone_url_http"></a> [aws\_codecommit\_clone\_url\_http](#output\_aws\_codecommit\_clone\_url\_http) | AWS CodeCommit HTTP based clone URL |
| <a name="output_aws_codecommit_clone_url_ssh"></a> [aws\_codecommit\_clone\_url\_ssh](#output\_aws\_codecommit\_clone\_url\_ssh) | AWS CodeCommit SSH based clone URL |
| <a name="output_aws_codecommit_consumer_clone_url_http"></a> [aws\_codecommit\_consumer\_clone\_url\_http](#output\_aws\_codecommit\_consumer\_clone\_url\_http) | AWS CodeCommit Consumer repo HTTP based clone URL |
| <a name="output_aws_codecommit_consumer_clone_url_ssh"></a> [aws\_codecommit\_consumer\_clone\_url\_ssh](#output\_aws\_codecommit\_consumer\_clone\_url\_ssh) | AWS CodeCommit Consumer repo SSH based clone URL |
| <a name="output_aws_codecommit_producer_clone_url_http"></a> [aws\_codecommit\_producer\_clone\_url\_http](#output\_aws\_codecommit\_producer\_clone\_url\_http) | AWS CodeCommit Producer repo HTTP based clone URL |
| <a name="output_aws_codecommit_producer_clone_url_ssh"></a> [aws\_codecommit\_producer\_clone\_url\_ssh](#output\_aws\_codecommit\_producer\_clone\_url\_ssh) | AWS CodeCommit Producer repo SSH based clone URL |
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | n/a |
| <a name="output_aws_vpc_id"></a> [aws\_vpc\_id](#output\_aws\_vpc\_id) | ############################################################################### VPC ############################################################################### |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Amazon EKS Cluster Endpoint address |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | ############################################################################### Cluster ############################################################################### |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The Amazon Resource Name (ARN) of the cluster, use |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | Amazon EKS Cluster Security Group ID |
| <a name="output_ecr_argoworkflow_container"></a> [ecr\_argoworkflow\_container](#output\_ecr\_argoworkflow\_container) | URL for Amazon ECR stored Argo Workflows container |
| <a name="output_ecr_consumer_container"></a> [ecr\_consumer\_container](#output\_ecr\_consumer\_container) | URL for Amazon ECR stored Consumer container |
| <a name="output_ecr_helm_chart_url"></a> [ecr\_helm\_chart\_url](#output\_ecr\_helm\_chart\_url) | URL for Amazon ECR stored chart |
| <a name="output_ecr_producer_container"></a> [ecr\_producer\_container](#output\_ecr\_producer\_container) | URL for Amazon ECR stored Producer container |
| <a name="output_karpenter_instance_profile"></a> [karpenter\_instance\_profile](#output\_karpenter\_instance\_profile) | Instance profile that will be used on Karpenter provisioned instances |
| <a name="output_karpenter_irsa"></a> [karpenter\_irsa](#output\_karpenter\_irsa) | IAM Role for Karpenter Service Account |
| <a name="output_lb_controller_irsa"></a> [lb\_controller\_irsa](#output\_lb\_controller\_irsa) | IAM Role for Load Balancer Controller Service Account |
| <a name="output_tenant_terraform_state_bucket_name"></a> [tenant\_terraform\_state\_bucket\_name](#output\_tenant\_terraform\_state\_bucket\_name) | Amazon S3 bucket name for Terraform state |
