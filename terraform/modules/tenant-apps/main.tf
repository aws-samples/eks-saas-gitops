resource "random_string" "random_suffix" {
  length  = 3
  special = false
  upper   = false
}

# PRODUCER INFRAESTRUCTURE
resource "aws_s3_bucket" "producer_bucket" {
  count  = var.enable_producer == true ? 1 : 0
  bucket = "producer-${var.bucket_name}-${random_string.random_suffix.result}"
  acl    = "private"

  tags = {
    Name = var.bucket_name
  }
}
# TBD: ADD IRSA

# CONSUMER INFRAESTRUCTURE
resource "aws_s3_bucket" "consumer_bucket" {
  count  = var.enable_consumer == true ? 1 : 0
  bucket = "consumer-${var.bucket_name}-${random_string.random_suffix.result}"
  acl    = "private"

  tags = {
    Name = var.bucket_name
  }
}
# TBD: ADD IRSA