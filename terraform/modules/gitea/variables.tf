variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "gitea_port" {
  description = "Port for Gitea HTTP service"
  default     = "3000"
}

variable "gitea_ssh_port" {
  description = "Port for Gitea SSH service"
  default     = "222"
}

variable "gitea_admin_user" {
  description = "Gitea admin username"
  type        = string
  default     = "gitadmin"
}

variable "gitea_admin_password" {
  description = "Gitea admin password"
  type        = string
  sensitive   = true
}

variable "eks_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "vscode_vpc_cidr" {
  description = "CIDR block of the VSCode VPC"
  type        = string
  default     = "10.0.0.0/16"
}
