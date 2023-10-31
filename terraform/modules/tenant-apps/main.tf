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
resource "aws_s3_bucket" "producer_bucket" {
  count  = var.enable_producer == true ? 1 : 0
  bucket = "producer-${var.tenant_id}-${random_string.random_suffix.result}"

  tags = {
    Name = var.tenant_id
  }
}

# CONSUMER INFRAESTRUCTURE
resource "aws_s3_bucket" "consumer_bucket" {
  count  = var.enable_consumer == true ? 1 : 0
  bucket = "consumer-${var.tenant_id}-${random_string.random_suffix.result}"

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
