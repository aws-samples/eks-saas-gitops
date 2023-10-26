# AWS Codebuild Terraform Module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_codebuild_project.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_iam_role.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_security_group.code_build_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_id"></a> [bucket\_id](#input\_bucket\_id) | Amazon S3 bucket ID | `string` | n/a | yes |
| <a name="input_build_timeout"></a> [build\_timeout](#input\_build\_timeout) | AWS Codebuild build timeout | `string` | `"5"` | no |
| <a name="input_codebuild_description"></a> [codebuild\_description](#input\_codebuild\_description) | Description for AWS Codebuild project | `string` | `"Sample Docker build"` | no |
| <a name="input_codebuild_project_name"></a> [codebuild\_project\_name](#input\_codebuild\_project\_name) | Name for AWS Codebuild project | `string` | n/a | yes |
| <a name="input_iam_policy"></a> [iam\_policy](#input\_iam\_policy) | AWS Codebuild IAM Policy | `any` | `"{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Sid\": \"Stmt1652709134956\",\n      \"Action\": \"*\",\n      \"Effect\": \"Allow\",\n      \"Resource\": \"*\"\n    }\n  ]\n}\n"` | no |
| <a name="input_private_subnet_list"></a> [private\_subnet\_list](#input\_private\_subnet\_list) | List of the Amazon VPC Subnets | `list(string)` | `[]` | no |
| <a name="input_repo_uri"></a> [repo\_uri](#input\_repo\_uri) | Amazon ECR repo URI | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Amazon VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of AWS CodeBuild project |
| <a name="output_id"></a> [id](#output\_id) | ID of AWS CodeBuild project |
