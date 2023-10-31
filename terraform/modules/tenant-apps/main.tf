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
resource "aws_sqs_queue" "producer_sqs" {
  count  = var.enable_producer == true ? 1 : 0
  name = "producer-${var.tenant_id}-${random_string.random_suffix.result}"

  tags = {
    Name = var.tenant_id
  }
}

# CONSUMER INFRAESTRUCTURE
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

# PAYMENTS INFRAESTRUCTURE
# resource "aws_s3_bucket" "payments_bucket" {
#   count  = var.enable_payments == true ? 1 : 0
#   bucket = "payments-${var.tenant_id}-${random_string.random_suffix.result}"

#   tags = {
#     Name = var.tenant_id
#   }
# }
