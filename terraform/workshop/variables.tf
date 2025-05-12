variable "name" {
  description = "Stack name"
  type        = string
  default     = "eks-saas-gitops"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1" # Setting a default region
}

variable "vpc_cidr" {
  description = "Amazon VPC CIDR Block"
  type        = string
  default     = "10.35.0.0/16"
}

variable "cluster_version" {
  description = "Amazon EKS Cluster version"
  type        = string
  default     = "1.32"
}

variable "public_key_file_path" {
  description = "Public key file path, used for clone CodeCommit repo, you should have private key locally"
  type        = string
  default     = ""
}

variable "clone_directory" {
  description = "Directory to clone CodeCommit repos"
  type        = string
  default     = "/tmp"
}

variable "flux2_sync_secret_values" {
  description = "This is created by install.sh script during execution"
  default     = "./flux-secrets.yaml"
}

variable "git_branch" {
  description = "Branch of the Git repository"
  type        = string
  default     = "main"
}

variable "kustomization_path" {
  description = "Path for Kustomization tool"
  type        = string
  default     = "gitops/clusters/production"
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
  default     = "admin"
}

variable "microservices" {
  description = "Configuration for each microservice"
  type = map(object({
    description : string
    default_branch : string
    codebuild_project_name : string
    pipeline_name : string
  }))
  default = {
    "producer" = {
      description            = "Producer microservice repository",
      default_branch         = "main",
      codebuild_project_name = "producer-codebuild",
      pipeline_name          = "producer-pipeline",
    },
    "consumer" = {
      description            = "Consumer microservice repository",
      default_branch         = "main",
      codebuild_project_name = "consumer-codebuild",
      pipeline_name          = "consumer-pipeline",
    },
    "payments" = {
      description            = "Payments microservice repository",
      default_branch         = "main",
      codebuild_project_name = "payments-codebuild",
      pipeline_name          = "payments-pipeline",
    },
    "onboarding_service" = {
      description            = "Onboarding microservice repository",
      default_branch         = "main",
      codebuild_project_name = "onboarding-codebuild",
      pipeline_name          = "onboarding-pipeline",
    }
  }
}
