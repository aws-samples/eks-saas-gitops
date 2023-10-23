variable "private_subnet_list" {
  default = []
}

variable "codebuild_project_name" {

}

variable "codebuild_description" {
  default = "Sample Docker build"
}

variable "build_timeout" {
  default = "5"
}

variable "vpc_id" {

}

variable "security_group_ids_list" {
  default = []
}

variable "tags" {
  default = {}
}

variable "iam_policy" {
  default = <<EOF
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

variable "bucket_id" {}

variable "repo_uri" {}