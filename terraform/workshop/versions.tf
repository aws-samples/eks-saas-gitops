terraform {
  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "0.6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
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
      version = "= 3.7.2"
    }
  }
  required_version = ">= 1.0"
}
