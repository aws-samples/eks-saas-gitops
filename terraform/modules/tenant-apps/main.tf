resource "random_string" "random_suffix" {
  length  = 3
  special = false
  upper   = false
}

# PRODUCER INFRAESTRUCTURE
resource "aws_s3_bucket" "producer_bucket" {
  count  = var.enable_producer == true ? 1 : 0
  bucket = "producer-${var.tenant_id}-${random_string.random_suffix.result}"

  tags = {
    Name = var.tenant_id
  }
}

resource "aws_s3_bucket_acl" "producer" {
  bucket = aws_s3_bucket.producer_bucket[0].id
}

# TBD: ADD IRSA

# CONSUMER INFRAESTRUCTURE
resource "aws_s3_bucket" "consumer_bucket" {
  count  = var.enable_consumer == true ? 1 : 0
  bucket = "consumer-${var.tenant_id}-${random_string.random_suffix.result}"

  tags = {
    Name = var.tenant_id
  }
}

resource "aws_s3_bucket_acl" "consumer" {
  bucket = aws_s3_bucket.consumer_bucket[0].id
}

# TBD: ADD IRSA