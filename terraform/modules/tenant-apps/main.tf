resource "random_string" "random_suffix" {
  length  = 3
  special = false
  upper   = false

  lifecycle {
    ignore_changes = [
      length
    ]
  }
}

# PRODUCER INFRAESTRUCTURE
#resource "aws_iam_policy" "producer-policy" {
#  name        = "${var.tenant_id}-producer-policy"
#  policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Action = [
#          "sqs:Write*",
#        ]
#        Effect   = "Allow"
#        Resource = [
#        ""
#        ]
#      },
#    ]
#  })
#}
#
#module "producer_irsa_role" {
#  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#  role_name = "${var.tenant_id}-producer-role"
#
#  role_policy_arns = {
#    policy = aws_iam_policy.producer-policy[0].arn
#  }
#
#  oidc_providers = {
#    main = {
#      provider_arn               = data.aws_eks_cluster.eks-saas-gitops.identity.0.oidc.0.issuer
#      namespace_service_accounts = ["${var.tenant_id}:producer"]
#    }
#  }
#}

# CONSUMER INFRAESTRUCTURE
resource "aws_sqs_queue" "consumer_sqs" {
  count  = var.enable_consumer == true ? 1 : 0
  name = "consumer-${var.tenant_id}-${random_string.random_suffix.result}"

  tags = {
    Name = var.tenant_id
  }
}
resource "aws_ssm_parameter" "dedicated_consumer_sqs" {
  count  = var.enable_consumer == true ? 1 : 0
  name  = "/${var.tenant_id}/consumer_sqs"
  type  = "String"
  value = aws_sqs_queue.consumer_sqs[0].arn
}
resource "aws_ssm_parameter" "shared_consumer_sqs" {
  count  = var.enable_consumer == false ? 1 : 0
  name  = "/${var.tenant_id}/consumer_sqs"
  type  = "String"
  value = data.aws_ssm_parameter.pool_1_consumer_sqs[0].value
}

resource "aws_dynamodb_table" "consumer_ddb" {
  count  = var.enable_consumer == true ? 1 : 0
  name = "consumer-${var.tenant_id}-${random_string.random_suffix.result}"
  hash_key = "primary_key"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "primary_key"
    type = "S"
  }

  tags = {
    Name = var.tenant_id
  }
}
resource "aws_ssm_parameter" "dedicated_consumer_ddb" {
  count  = var.enable_consumer == true ? 1 : 0
  name  = "/${var.tenant_id}/consumer_ddb"
  type  = "String"
  value = aws_dynamodb_table.consumer_ddb[0].arn
}
resource "aws_ssm_parameter" "shared_consumer_ddb" {
  count  = var.enable_consumer == false ? 1 : 0
  name  = "/${var.tenant_id}/consumer_ddb"
  type  = "String"
  value = data.aws_ssm_parameter.pool_1_consumer_ddb[0].value
}

# PAYMENTS INFRASTRUCTURE

# resource "aws_s3_bucket" "payments_bucket" {
#   count  = var.enable_payments == true ? 1 : 0
#   bucket = "${var.tenant_id}-payments-${random_string.random_suffix.result}"

#   tags = {
#     Name = var.tenant_id
#   }
# }

# resource "aws_ssm_parameter" "dedicated_payments_bucket" {
#   count  = var.enable_payments == true ? 1 : 0
#   name  = "/${var.tenant_id}/payments_bucket"
#   type  = "String"
#   value = aws_s3_bucket.payments_bucket[0].arn
# }

# resource "aws_ssm_parameter" "shared_payments_bucket" {
#   count  = var.enable_payments == false ? 1 : 0
#   name  = "/${var.tenant_id}/payments_bucket"
#   type  = "String"
#   value = data.aws_ssm_parameter.pool_1_payments_bucket[0].value
# }