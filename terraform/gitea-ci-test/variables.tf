variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "gitea-ci-test"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ip" {
  description = "IP address allowed to access Gitea (format: x.x.x.x/32)"
  type        = string
  default     = "136.60.37.246/32" # Empty string means no specific IP is allowed
}

variable "gitea_admin_password" {
  description = "Password for the Gitea admin user"
  type        = string
  default     = "AdminPassword123!" # Change this in production
  sensitive   = true
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
    }
  }
}
