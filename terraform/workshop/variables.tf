variable "name" {
  description = "Stack name"
  type        = string
  default     = "eks-saas-gitops"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "Amazon VPC CIDR Block"
  type        = string
  default     = "10.35.0.0/16"
}

variable "cluster_version" {
  description = "Amazon EKS Cluster version"
  type        = string
  default     = "1.27"
}

variable "public_key_file_path" {
  description = "Public key file path, used for clone CodeCommit repo, you should have private key locally"
  type        = string
  default     = "~/.ssh/id_rsa_git.pub"
}

variable "kustomization_path" {
  description = "Path for Kustomization tool"
  type        = string
  default     = "gitops/clusters/production"
}