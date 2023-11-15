# Example Tenant Apps Terraform module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_consumer_irsa_role"></a> [consumer\_irsa\_role](#module\_consumer\_irsa\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_producer_irsa_role"></a> [producer\_irsa\_role](#module\_producer\_irsa\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.consumer_ddb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.consumer-iampolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.producer-iampolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.sto-readonly-role-policy-attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_sqs_queue.consumer_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_ssm_parameter.dedicated_consumer_ddb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.dedicated_consumer_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.shared_consumer_ddb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.shared_consumer_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [random_string.random_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.eks-saas-gitops](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_ssm_parameter.pool_1_consumer_ddb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.pool_1_consumer_sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_consumer"></a> [enable\_consumer](#input\_enable\_consumer) | Defines if the Consumer app infraestructure will be deployed | `bool` | `true` | no |
| <a name="input_enable_payments"></a> [enable\_payments](#input\_enable\_payments) | Defines if the Payments app infraestructure will be deployed | `bool` | `true` | no |
| <a name="input_enable_producer"></a> [enable\_producer](#input\_enable\_producer) | Defines if the Producer app infraestructure will be deployed | `bool` | `true` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tentant identification | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_consumer_irsa_role"></a> [consumer\_irsa\_role](#output\_consumer\_irsa\_role) | IAM Role for Service account for Consumer microservice |
| <a name="output_producer_irsa_role"></a> [producer\_irsa\_role](#output\_producer\_irsa\_role) | IAM Role for Service account for Producer microservice |
