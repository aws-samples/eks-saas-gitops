variable "iam_policy" {
  description = "AWS Codepipeline IAM Policy"
  type        = any
  default     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1652709134956",
      "Action": "*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

variable "pipeline_name" {
  description = "Name for AWS Codepipeline"
  type        = string
}

variable "repo_name" {
  description = "AWS Codecommit repo name"
  type        = string
}

variable "branch_name" {
  description = "AWS Codecommit branch name"
  type        = string
  default     = "main"
}

variable "codebuild_project" {
  description = "Name for AWS Codebuild project"
  type        = string

}

variable "bucket_id" {
  description = "Amazon S3 bucket ID"
  type        = string
}