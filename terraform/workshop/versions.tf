terraform {
  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "0.6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.5"
    }
  }
  required_version = ">= 1.0"
}
