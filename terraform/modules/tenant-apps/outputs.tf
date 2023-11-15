output "producer_irsa_role" {
  description = "IAM Role for Service account for Producer microservice"
  value       = try(module.producer_irsa_role[0].iam_role_arn, null)
}

output "consumer_irsa_role" {
  description = "IAM Role for Service account for Consumer microservice"
  value       = try(module.consumer_irsa_role[0].iam_role_arn, null)
}
