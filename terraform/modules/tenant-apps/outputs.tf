output "producer_bucket_name" {
  value = try(aws_s3_bucket.producer_bucket[0].id, null)
}

output "consumer_bucket_name" {
  value = try(aws_s3_bucket.consumer_bucket[0].id, null)
}
