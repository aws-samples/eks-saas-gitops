output "producer_irsa_role" {
  value = try(module.producer_irsa_role[0].iam_role_arn, null)
}

output "consumer_irsa_role" {
  value = try(module.consumer_irsa_role[0].iam_role_arn, null)
}
