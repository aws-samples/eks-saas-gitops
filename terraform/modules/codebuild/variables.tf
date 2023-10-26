variable "private_subnet_list" {
  description = "List of the Amazon VPC Subnets"
  type        = list(string)
  default     = []
}

variable "codebuild_project_name" {
  description = "Name for AWS Codebuild project"
  type        = string
}

variable "codebuild_description" {
  description = "Description for AWS Codebuild project"
  type        = string
  default     = "Sample Docker build"
}

variable "build_timeout" {
  description = "AWS Codebuild build timeout"
  type        = string
  default     = "5"
}

variable "vpc_id" {
  description = "Amazon VPC ID"
  type        = string
}

# variable "security_group_ids_list" {
#   description = "List of Security Groups"
#   type        = list(string)
#   default     = []
# }

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

variable "iam_policy" {
  description = "AWS Codebuild IAM Policy"
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

variable "bucket_id" {
  description = "Amazon S3 bucket ID"
  type        = string
}

variable "repo_uri" {
  description = "Amazon ECR repo URI"
  type        = string
}