variable "cluster_endpoint" {
  description = "Amazon EKS Cluster endpoint URL"
  type        = string
}

variable "ca" {
  description = "Amazon EKS Certificate authority"
  type        = string
}

variable "token" {
  description = "Amazon EKS Cluster token"
  type        = string
}

variable "git_branch" {
  description = "Git branch name to be used by Flux"
  type        = string
  default     = "main"
}

variable "git_url" {
  description = "Git URL to be used by Flux"
  type        = string
}

variable "namespace" {
  description = "Flux default Kubernetes namespace"
  type        = string
  default     = "flux-system"
}

variable "activate_helm_controller" {
  description = "Defines if Helm controller should be deployed"
  type        = bool
  default     = true
}

variable "activate_image_automation_controller" {
  description = "Defines if image automation controller should be activated"
  type        = bool
  default     = true
}

variable "image_automation_controller_sa_annotations" {
  description = "Defines image automation controller SA annotations"
  type        = string
  default     = ""
}

variable "activate_image_reflection_controller" {
  description = "Defines if image automation controller should be activated"
  type        = bool
  default     = true
}

variable "image_reflection_controller_sa_annotations" {
  description = "Defines image reflection controller SA annotations"
  type        = string
  default     = ""
}

variable "activate_kustomize_controller" {
  description = "Defines if Kustomize controller should be activated"
  type        = bool
  default     = true
}

variable "activate_notification_controller" {
  description = "Defines if notification controller should be activated"
  type        = bool
  default     = true
}

variable "activate_source_controller" {
  description = "Defines if source controller should be activated"
  type        = bool
  default     = true
}

variable "kustomization_path" {
  default = "Path for Kustomization directory"
  type    = string
}

variable "flux2_sync_version" {
  description = "Flux2 sync helm chart version"
  type        = string
  default     = "1.8.2"
}

variable "flux2_version" {
  description = "Flux2 helm chart version"
  type        = string
  default     = "2.13.0"
}

variable "flux2_sync_secret_values" {
  description = "Content of the flux-secrets.yaml file"
  type        = string
  default     = ""
}

