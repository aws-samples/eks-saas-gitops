locals {
  name                 = var.name
  code_commit_username = "codecommit-user"
}

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
# SQS Queue to Trigger ArgoWorkflows
resource "aws_sqs_queue" "karpenter_interruption_queue" {
  name                    = local.name
  sqs_managed_sse_enabled = true
}

resource "aws_iam_policy" "karpenter_sqs_policy" {
  name        = "karpenter-sqs-interruption-policy"
  path        = "/"
  description = "karpenter-sqs-interruption-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "sqs:GetQueueUrl",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:ListMessageMoveTasks",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:PurgeQueue",
          "sqs:DeleteMessage"
        ],
        "Effect" : "Allow",
        "Resource" : [
          aws_sqs_queue.karpenter_interruption_queue.arn
        ]
      }
    ]
  })
}

module "karpenter_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.1"

  role_name                          = "karpenter_controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = var.cluster_name
  karpenter_controller_node_iam_role_arns = [aws_iam_role.karpenter_node_role.arn]

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

resource "aws_iam_policy_attachment" "karpenter_policy_attach_sqs" {
  name       = "karpenter-policy-attach-sqs"
  roles      = [module.karpenter_irsa_role.iam_role_name]
  policy_arn = aws_iam_policy.karpenter_sqs_policy.arn
  users      = []

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      roles, users
    ]
  }
  depends_on = [module.karpenter_irsa_role, aws_iam_policy.karpenter_sqs_policy]
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
        "Action" : [
          "iam:*",
          "ssm:GetParameter",
          "iam:PassRole",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Karpenter"
      },
      {
        "Action" : "ec2:TerminateInstances",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/Name" : "*karpenter*"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "ConditionalEC2Termination"
      }
    ]
  })

  depends_on = [
    module.karpenter_irsa_role
  ]
}
resource "aws_iam_policy_attachment" "karpenter_policy_attach" {
  name       = "karpenter-policy-attach"
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
  depends_on = [module.karpenter_irsa_role, aws_iam_policy.karpenter-policy]
}

################################################################################
# Argo Workflows needs
################################################################################
module "argo_workflows_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "argo-workflows-irsa-${var.name}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  oidc_providers = {
    one = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["argo-workflows:argoworkflows-sa", "argo-workflows:argo-workflows-server"]
    }
  }
}

resource "random_uuid" "uuid" {}

# To store argo artifacts
resource "aws_s3_bucket" "argo_artifacts" {
  bucket = "saasgitops-argo-${random_uuid.uuid.result}"

  tags = {
    Blueprint = var.name
  }
}

# SQS Queue to Trigger ArgoWorkflows
resource "aws_sqs_queue" "argoworkflows_onboarding_queue" {
  name                    = "argoworkflows-onboarding-queue"
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "argoworkflows_offboarding_queue" {
  name                    = "argoworkflows-offboarding-queue"
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "argoworkflows_deployment_queue" {
  name                    = "argoworkflows-deployment-queue"
  sqs_managed_sse_enabled = true
}

resource "aws_iam_policy" "argosensor-policy" {
  name        = "argosensor-policy"
  path        = "/"
  description = "argosensor-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "sqs:GetQueueUrl",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:ListMessageMoveTasks",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:PurgeQueue",
          "sqs:DeleteMessage"
        ],
        "Effect" : "Allow",
        "Resource" : [
          aws_sqs_queue.argoworkflows_onboarding_queue.arn,
          aws_sqs_queue.argoworkflows_offboarding_queue.arn,
          aws_sqs_queue.argoworkflows_deployment_queue.arn,
        ]
      }
    ]
  })
}

module "argo_events_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "argo-events-irsa"

  role_policy_arns = {
    policy = aws_iam_policy.argosensor-policy.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["argo-events:argo-events-sa"]
    }
  }

  depends_on = [aws_iam_policy.argosensor-policy]
}

################################################################################
# LB Controller IRSA
################################################################################
resource "aws_iam_policy" "lb-controller-irsa-policy" {
  name = "lb-controller-irsa-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:CreateServiceLinkedRole"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "iam:AWSServiceName" : "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateSecurityGroup"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags"
        ],
        "Resource" : "arn:aws:ec2:*:*:security-group/*",
        "Condition" : {
          "StringEquals" : {
            "ec2:CreateAction" : "CreateSecurityGroup"
          },
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        "Resource" : "arn:aws:ec2:*:*:security-group/*",
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ],
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "elasticloadbalancing:CreateAction" : [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          },
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ],
        "Resource" : "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ],
        "Resource" : "*"
      }
    ]
  })
}
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "lb-controller-irsa-${var.name}"

  role_policy_arns = {
    policy = aws_iam_policy.lb-controller-irsa-policy.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["aws-system:aws-load-balancer-controller"]
    }
  }
}

################################################################################
# TF Controller Service Account
################################################################################
module "tf_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "tf-controller-${var.name}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }


  oidc_providers = {
    main = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["flux-system:tf-runner", "flux-system:tf-controller"]
    }
  }
}
