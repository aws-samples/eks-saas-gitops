# Can overwrite default policy
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

variable "pipeline_name" {

}

variable "repo_name" {

}

variable "branch_name" {
  default = "master"
}

variable "codebuild_project" {
  
}

variable "bucket_id" {
  
}