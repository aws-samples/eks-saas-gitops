variable "name" {
  description = "Stack name"
  default     = "eks-saas-gitops"
}

variable "cluster_name" {
  description = "Name of Amazon EKS Cluster"
  default     = "eks-saas"
}

variable "cluster_oidc_provider_arn" {
  description = "OIDC ARN of Amazon EKS Cluster"
  default     = ""
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
  default     = "gitops-saas/application-chart"
}

variable "argoworkflow_container_repo" {
  description = "Repository for Argo Workflows container image"
  type        = string
  default     = "argoworkflow-container"
}

variable "microservices" {
  description = "Configuration for each microservice"
  type = map(object({
    description : string
    default_branch : string
  }))
  default = {
    "producer" = {
      description    = "Producer microservice repository",
      default_branch = "main",
    },
    "consumer" = {
      description    = "Consumer microservice repository",
      default_branch = "main",
    },
    "payments" = {
      description    = "Payments microservice repository",
      default_branch = "main",
    },
    "onboarding_service" = {
      description    = "Onboarding microservice repository",
      default_branch = "main",
    }
  }
}
