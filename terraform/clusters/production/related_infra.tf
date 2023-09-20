################################################################################
# Karpenter Role to use in nodes created by Karpenter
################################################################################

resource "aws_iam_role" "karpenter_node_role" {
  name               = "KarpenterNodeRole-${var.name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "container_registry_policy" {
  name       = "KarpenterAmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.karpenter_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      roles
    ]
  }
}

resource "aws_iam_policy_attachment" "amazon_eks_worker_node_policy" {
  name       = "KarpenterAmazonEKSWorkerNodePolicy"
  roles      = [aws_iam_role.karpenter_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      roles
    ]
  }
}

resource "aws_iam_policy_attachment" "amazon_eks_cni_policy" {
  name       = "KarpenterAmazonEKS_CNI_Policy"
  roles      = [aws_iam_role.karpenter_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      roles
    ]
  }
}

resource "aws_iam_policy_attachment" "amazon_eks_ssm_policy" {
  name       = "KarpenterAmazonSSMManagedInstanceCore"
  roles      = [aws_iam_role.karpenter_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "KarpenterNodeInstanceProfile-${var.name}"
  role = aws_iam_role.karpenter_node_role.name
}

################################################################################
# Karpenter IRSA
################################################################################
module "karpenter_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                          = "karpenter_controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [aws_iam_role.karpenter_node_role.arn]

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

resource "aws_iam_policy" "karpenter-policy" {
  name        = "karpenter-policy"
  path        = "/"
  description = "karpenter-policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "*",
        "Resource" : "*"
      }
    ]
  })
}

# TODO: Improve policy defined here, to a more specific one
resource "aws_iam_policy_attachment" "karpenter_policy_attach" {
  name       = "karpenter-admin"
  roles      = [module.karpenter_irsa_role.iam_role_name]
  policy_arn = aws_iam_policy.karpenter-policy.arn
  users      = []

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      roles, users
    ]
  }
}

################################################################################
# Argo Workflows needs
################################################################################
module "argo_workflows_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "argo-workflows-irsa"

  # TODO: Change to specific policy
  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["argo-workflows:full-permissions-service-account", "argo-workflows:argo-workflows-server"]
    }
  }
}


resource "random_uuid" "uuid" {}

# To store argo artifacts
resource "aws_s3_bucket" "argo-artifacts" {
  bucket = "saasgitops-argo-${random_uuid.uuid.result}"

  tags = {
    Blueprint = var.name
  }
}

################################################################################
# LB Controller IRSA
################################################################################
module "lb-controller-irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "lb-controller-irsa"

  # TODO: Change to specific policy
  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["aws-system:aws-load-balancer-controller"]
    }
  }
}

# TODO Provision ECR repo for Helm Chart and Microsservices
################################################################################
# ECR repositories
################################################################################
resource "aws_ecr_repository" "tenant_helm_chart" {
  name                 = var.tenant_helm_chart_repo
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "argoworkflow_container" {
  name                 = var.argoworkflow_container_repo
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "consumer_container" {
  name                 = var.consumer_container_repo
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "producer_container" {
  name                 = var.producer_container_repo
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}



################################################################################
# EBS CSI Driver IRSA
################################################################################
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "ebs-csi"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


################################################################################
# TERRAFORM STATE TENANT S3_BUCKET
################################################################################

# To store argo artifacts
resource "aws_s3_bucket" "tenant-terraform-state-bucket" {
  bucket = "saasgitops-terraform-${random_uuid.uuid.result}"

  tags = {
    Blueprint = var.name
  }
}

################################################################################
# CODE COMMIT needs for flux
################################################################################
module "codecommit-flux" {
  source          = "lgallard/codecommit/aws"
  version         = "0.2.1"
  default_branch  = "main"
  description     = "Flux GitOps repository"
  repository_name = "eks-saas-gitops-aws"
}

resource "aws_iam_user" "codecommit-user" {
  name = "codecommit-user"
}

resource "aws_iam_user_policy_attachment" "codecommit-user-attach" {
  user       = aws_iam_user.codecommit-user.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitPowerUser"
}