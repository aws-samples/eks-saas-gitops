variable "name" {
  description = "Stack name"
  default = "eks-saas-gitops"
}

variable "cluster_name" {
  description = "Name of Amazon EKS Cluster"
  default = "eks-saas"
}

variable "cluster_oidc_provider_arn" {
  description = "OIDC ARN of Amazon EKS Cluster"
  default = ""
}

# TBD: This could be a loop like we are using for microsservices
variable "tenant_helm_chart_repo" {
  description = "Repository for Tenant Helm chart"
  type        = string
  default     = "gitops-saas/helm-tenant-chart"
}

variable "application_helm_chart_repo" {
  description = "Repository for Application chart"
  type        = string
  default = "gitops-saas/application-chart"
}

variable "argoworkflow_container_repo" {
  description = "Repository for Argo Workflows container image"
  type        = string
  default     = "argoworkflow-container"
}

variable "vpc_id" {
  description = "ID of the VPC to deploy CodeBuild projects"
}

variable "private_subnets" {
  description = "List of private subnets to place CodeBuild project"
}

variable "microservices" {
  description = "Configuration for each microservice"
  type = map(object({
    description            : string
    default_branch         : string
    codebuild_project_name : string
    pipeline_name          : string
  }))
  default = {
    "producer" = {
      description = "Producer microservice repository",
      default_branch = "main",
      codebuild_project_name = "producer-codebuild",
      pipeline_name = "producer-pipeline",
    },
    "consumer" = {
      description = "Consumer microservice repository",
      default_branch = "main",
      codebuild_project_name = "consumer-codebuild",
      pipeline_name = "consumer-pipeline",
    },
    "payments" = {
      description = "Payments microservice repository",
      default_branch = "main",
      codebuild_project_name = "payments-codebuild",
      pipeline_name = "payments-pipeline",
    }
  }
}

variable "public_key_file_path" {
  description = "Path to public key file"
  default = "~/.ssh/id_rsa.pub"
}

