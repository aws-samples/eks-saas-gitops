
# AWS Codepipeline Terraform Module

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
| [aws_codepipeline.pipeline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | resource |
| [aws_iam_role.codepipeline_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codepipeline_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_branch_name"></a> [branch\_name](#input\_branch\_name) | AWS Codecommit branch name | `string` | `"main"` | no |
| <a name="input_bucket_id"></a> [bucket\_id](#input\_bucket\_id) | Amazon S3 bucket ID | `string` | n/a | yes |
| <a name="input_codebuild_project"></a> [codebuild\_project](#input\_codebuild\_project) | Name for AWS Codebuild project | `string` | n/a | yes |
| <a name="input_iam_policy"></a> [iam\_policy](#input\_iam\_policy) | AWS Codepipeline IAM Policy | `any` | `"{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Sid\": \"Stmt1652709134956\",\n      \"Action\": \"*\",\n      \"Effect\": \"Allow\",\n      \"Resource\": \"*\"\n    }\n  ]\n}\n"` | no |
| <a name="input_pipeline_name"></a> [pipeline\_name](#input\_pipeline\_name) | Name for AWS Codepipeline | `string` | n/a | yes |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | AWS Codecommit repo name | `string` | n/a | yes |

## Outputs

No outputs.
