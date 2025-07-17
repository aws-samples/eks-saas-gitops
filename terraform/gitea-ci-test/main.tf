provider "aws" {
  region = var.aws_region
}

# Random UUID for unique resource names
resource "random_uuid" "this" {}

################################################################################
# VPC for Gitea (simplified for testing)
################################################################################
resource "aws_vpc" "gitea_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "gitea_subnet" {
  vpc_id                  = aws_vpc.gitea_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.name}-subnet"
  }
}

resource "aws_internet_gateway" "gitea_igw" {
  vpc_id = aws_vpc.gitea_vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "gitea_rt" {
  vpc_id = aws_vpc.gitea_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gitea_igw.id
  }

  tags = {
    Name = "${var.name}-rt"
  }
}

resource "aws_route_table_association" "gitea_rta" {
  subnet_id      = aws_subnet.gitea_subnet.id
  route_table_id = aws_route_table.gitea_rt.id
}

################################################################################
# SSM Parameter for Gitea admin password
################################################################################
resource "aws_ssm_parameter" "gitea_admin_password" {
  name        = "/eks-saas-gitops/gitea-admin-password"
  description = "Gitea admin password"
  type        = "SecureString"
  value       = var.gitea_admin_password

  tags = {
    Name = "${var.name}-gitea-admin-password"
  }
}

################################################################################
# Gitea Module
################################################################################
module "gitea" {
  source = "../modules/gitea"

  name               = "${var.name}-gitea"
  vpc_id             = aws_vpc.gitea_vpc.id
  vpc_cidr           = var.vpc_cidr
  subnet_ids         = [aws_subnet.gitea_subnet.id]
  vscode_vpc_cidr    = var.vpc_cidr
  gitea_port         = 3000
  gitea_ssh_port     = 222
  allowed_ip         = var.allowed_ip
  gitea_admin_password = var.gitea_admin_password
  eks_security_group_id = aws_security_group.dummy_sg.id # Dummy SG for testing
}

# Dummy security group to simulate EKS cluster SG
resource "aws_security_group" "dummy_sg" {
  name        = "${var.name}-dummy-sg"
  description = "Dummy security group to simulate EKS cluster"
  vpc_id      = aws_vpc.gitea_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-dummy-sg"
  }
}

################################################################################
# ECR Repositories for Microservices
################################################################################
resource "aws_ecr_repository" "microservice_container" {
  for_each = var.microservices

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = each.key
    Description = each.value.description
  }
}

################################################################################
# Outputs
################################################################################
output "gitea_public_ip" {
  description = "Public IP of the Gitea server"
  value       = module.gitea.public_ip
}

output "gitea_url" {
  description = "URL of the Gitea server"
  value       = "http://${module.gitea.public_ip}:3000"
}

output "ecr_repository_urls" {
  value = { for key, repo in aws_ecr_repository.microservice_container : key => repo.repository_url }
  description = "The URLs of the ECR repositories."
}
