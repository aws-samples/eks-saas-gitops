################################################################################
# ECR repositories for Utilities
################################################################################
resource "aws_ecr_repository" "tenant_helm_chart" {
  name                 = var.tenant_helm_chart_repo
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "application_helm_chart" {
  name                 = var.application_helm_chart_repo
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "argoworkflow_container" {
  name                 = var.argoworkflow_container_repo
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

################################################################################
# Microsservices and ECR Repositories
################################################################################
resource "random_uuid" "this" {}

resource "aws_s3_bucket" "codeartifacts" {
  bucket        = "codestack-artifacts-bucket-${random_uuid.this.result}"
  force_destroy = true
}

resource "aws_ecr_repository" "microservice_container" {
  for_each = var.microservices

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = each.key
    Description = each.value.description
  }
}