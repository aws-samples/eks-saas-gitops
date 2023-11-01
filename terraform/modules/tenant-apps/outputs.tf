output "consumer_sqs_arn" {
  value = try(aws_sqs_queue.consumer_sqs[0].arn, null)
}

output "consumer_ddb_arn" {
  value = try(aws_dynamodb_table.consumer_ddb[0].arn, null)
}
