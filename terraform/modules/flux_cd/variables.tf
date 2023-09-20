variable "cluster_endpoint" {}

variable "ca" {}

variable "token" {}

variable "git_branch" {
  default = "main"
}

# variable "git_username" {
# }


# variable "git_password" {
# }

variable "git_url" {}

variable "namespace" {
  default = "flux-system"
}

variable "activate_helm_controller" {
  default = true
}

variable "activate_image_automation_controller" {
  default = false
}

variable "image_automation_controller_sa_annotations" {
  default = ""
}

variable "activate_image_reflection_controller" {
  default = false
}

variable "image_reflection_controller_sa_annotations" {
  default = ""
}

variable "activate_kustomize_controller" {
  default = true
}

variable "activate_notification_controller" {
  default = true
}

variable "activate_source_controller" {
  default = true
}

variable "kustomization_path" {
  
}

variable "values_path" {
  
}