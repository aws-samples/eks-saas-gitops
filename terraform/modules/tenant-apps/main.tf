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

# ---------------------[ PRODUCER INFRASTRUCTURE ]--------------------
# IAM POLICY FOR PRODUCER TO ACCESS CONSUMER SQS QUEUE
resource "aws_iam_policy" "producer-iampolicy" {
  count  = var.enable_consumer == true ? 1 : 0
  name        = "producer-policy-${var.tenant_id}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "ssm:GetParameter",
        ]
        Effect   = "Allow"
        Resource = [
          aws_sqs_queue.consumer_sqs[0].arn,
          aws_ssm_parameter.dedicated_consumer_sqs[0].arn
        ]
      },
    ]
  })
}

# IF DEDICATED PRODUCER AND CONSUMER:
module "producer_irsa_role" {
  count  = var.enable_producer == true && var.enable_consumer == true ? 1 : 0
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "producer-role-${var.tenant_id}"

  role_policy_arns = {
    policy = aws_iam_policy.producer-iampolicy[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = replace(data.aws_eks_cluster.eks-saas-gitops.identity[0].oidc[0].issuer, "https://", "")
      namespace_service_accounts = ["${var.tenant_id}:producer"]
    }
  }
}

# IF SHARED PRODUCER AND DEDICATED CONSUMER (HYBRID):
resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  count  = var.enable_producer == false && var.enable_consumer == true ? 1 : 0
  role       = "producer-role-pooled-1"
  policy_arn = aws_iam_policy.producer-iampolicy[0].arn
}

# ---------------------[ CONSUMER INFRASTRUCTURE ]--------------------
resource "aws_iam_policy" "consumer-iampolicy" {
  count  = var.enable_consumer == true ? 1 : 0
  name        = "consumer-policy-${var.tenant_id}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ListQueues",
          "sqs:GetQueueUrl",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:ListMessageMoveTasks",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:DeleteMessage",
          "dynamodb:PutItem",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = [
          aws_dynamodb_table.consumer_ddb[0].arn,
          aws_sqs_queue.consumer_sqs[0].arn,
          aws_ssm_parameter.dedicated_consumer_sqs[0].arn,
          aws_ssm_parameter.dedicated_consumer_ddb[0].arn
        ]
      },
    ]
  })
}
module "consumer_irsa_role" {
  count  = var.enable_consumer == true ? 1 : 0
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "consumer-role-${var.tenant_id}"

  role_policy_arns = {
    policy = aws_iam_policy.consumer-iampolicy[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = replace(data.aws_eks_cluster.eks-saas-gitops.identity[0].oidc[0].issuer, "https://", "")
      namespace_service_accounts = ["${var.tenant_id}:consumer"]
    }
  }
}
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
  hash_key = "tenant_id"
  range_key = "message_id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "message_id"
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

# ---------------------[ PAYMENTS INFRASTRUCTURE ]--------------------

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