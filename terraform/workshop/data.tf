# DataSources
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vscode" {
  filter {
    name   = "tag:Name"
    values = ["eks-saas-gitops-vscode-vpc"]
  }
}

# Matches VS Code SG
data "aws_security_group" "vscode" {
  tags = {
    Name = "eks-saas-gitops-vscode-sg"
  }
}

data "aws_route_tables" "vscode" {
  vpc_id = data.aws_vpc.vscode.id
}