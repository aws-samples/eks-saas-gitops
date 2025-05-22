locals {
  name   = var.name
  region = var.aws_region

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint = var.name
  }
}

################################################################################
# VPC and Roles
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
  }

  tags = local.tags
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "ebs-csi-${local.name}"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "image_automation_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "image-automation-${local.name}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["flux-system:image-automation-controller", "flux-system:image-reflector-controller"]
    }
  }
}
################################################################################
# EKS Cluster
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.12"

  cluster_name                   = local.name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true


  node_security_group_tags = {
    "kubernetes.io/cluster/${local.name}" = null
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      most_recent              = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.gitops_saas_infra.karpenter_node_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  ]
  eks_managed_node_groups = {
    baseline-infra = {
      instance_types = ["m5.large"]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
      labels = {
        node-type = "applications"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

################################################################################
# Gitea
################################################################################
resource "random_password" "gitea_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the password in SSM Parameter Store for future reference
resource "aws_ssm_parameter" "gitea_password" {
  name        = "/${local.name}/gitea-admin-password"
  description = "Gitea admin password"
  type        = "SecureString"
  value       = random_password.gitea_admin.result
}

module "gitea" {
  source          = "../modules/gitea"
  name            = "${local.name}-gitea"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = local.vpc_cidr
  subnet_ids      = module.vpc.public_subnets
  vscode_vpc_cidr = data.aws_vpc.vscode.cidr_block

  gitea_port            = var.gitea_port
  gitea_ssh_port        = var.gitea_ssh_port
  gitea_admin_user      = var.gitea_admin_user
  gitea_admin_password  = random_password.gitea_admin.result
  eks_security_group_id = module.eks.node_security_group_id
}

output "gitea_password_command" {
  value = "aws ssm get-parameter --name '/${local.name}/gitea-admin-password' --with-decryption --query 'Parameter.Value' --output text"
}

# TODO: Create a count to disable this peering config if want to deploy from local terminal
resource "aws_vpc_peering_connection" "vscode_to_gitea" {
  peer_vpc_id = data.aws_vpc.vscode.id
  vpc_id      = module.vpc.vpc_id
  auto_accept = true

  tags = {
    Name = "vscode-to-gitea-peering"
  }
}

# Add routes for the peering connection
resource "aws_route" "vscode_to_gitea" {
  count                     = length(data.aws_route_tables.vscode.ids)
  route_table_id            = data.aws_route_tables.vscode.ids[count.index]
  destination_cidr_block    = module.vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vscode_to_gitea.id
}


resource "aws_route" "gitea_to_vscode" {
  count                     = length(module.vpc.private_route_table_ids) + length(module.vpc.public_route_table_ids)
  route_table_id            = element(concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids), count.index)
  destination_cidr_block    = data.aws_vpc.vscode.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vscode_to_gitea.id
}

################################################################################
# Kubernetes Resources
################################################################################

# Create the flux-system namespace, needed for GitOps SaaS Infra ConfigMap
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  depends_on = [module.eks]
}

################################################################################
# Gitea Repositories
################################################################################

# Get the Gitea token from SSM Parameter Store
data "aws_ssm_parameter" "gitea_token" {
  name            = "/eks-saas-gitops/gitea-flux-token"
  with_decryption = true

  # Add a depends_on to ensure the Gitea instance has had time to create the token
  depends_on = [module.gitea]
}

# Clone main repo
resource "gitea_repository" "eks-saas-gitops" {
  username                 = var.gitea_admin_user
  name                     = "eks-saas-gitops"
  description              = "GitOps SaaS Repository"
  private                  = false
  mirror                   = false
  migration_clone_addresse = "https://github.com/lusoal/gitops-manifests-template.git"
  migration_service        = "git"

  depends_on = [module.gitea, data.aws_ssm_parameter.gitea_token]
}

# Create repositories for each microservice with mirroring
resource "gitea_repository" "producer" {
  username                 = var.gitea_admin_user
  name                     = "producer"
  description              = "Producer microservice repository"
  private                  = false
  mirror                   = false
  migration_clone_addresse = "https://github.com/lusoal/producer-template.git"
  migration_service        = "git"

  depends_on = [module.gitea, data.aws_ssm_parameter.gitea_token]
}

resource "gitea_repository" "consumer" {
  username                 = var.gitea_admin_user
  name                     = "consumer"
  description              = "Consumer microservice repository"
  private                  = false
  mirror                   = false
  migration_clone_addresse = "https://github.com/lusoal/consumer-template.git"
  migration_service        = "git"

  depends_on = [module.gitea, data.aws_ssm_parameter.gitea_token]
}

resource "gitea_repository" "payments" {
  username                 = var.gitea_admin_user
  name                     = "payments"
  description              = "Payments microservice repository"
  private                  = false
  mirror                   = false
  migration_clone_addresse = "https://github.com/lusoal/payments-template.git"
  migration_service        = "git"

  depends_on = [module.gitea, data.aws_ssm_parameter.gitea_token]
}
