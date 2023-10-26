variable "name" {
  description = "Stack name"
  type        = string
  default     = "eks-saas-gitops"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = null
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

variable "git_branch" {
  description = "Branch of the Git repository"
  type        = string
  default     = "main"
}

variable "git_url" {
  description = "URL for the Git repository"
  type        = string
  default     = ""
}

variable "kustomization_path" {
  description = "Path for Kustomization tool"
  type        = string
  default     = "gitops/clusters/production"
}

variable "values_path" {
  description = "Path for Helm chart values"
  type        = string
  default     = "./values.yaml"
}

variable "tenant_helm_chart_repo" {
  description = "Repository for Tenant Helm chart"
  type        = string
  default     = "gitops-saas/helm-tenant-chart"
}

variable "argoworkflow_container_repo" {
  description = "Repository for Argo Workflows container image"
  type        = string
  default     = "argoworkflow-container"
}

variable "producer_container_repo" {
  description = "Repository for Producer container image"
  type        = string
  default     = "producer-container"
}

variable "consumer_container_repo" {
  description = "Repository for Consumer container image"
  type        = string
  default     = "consumer-container"
}

variable "payments_container_repo" {
  description = "Repository for Payments container image"
  type        = string
  default     = "payments-container"
}