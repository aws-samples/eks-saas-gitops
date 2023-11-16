output "producer" {
  description = "Outputs for Producer microservice"
  value = {
    "irsa_role" : try(module.producer_irsa_role[0].iam_role_arn, null)
  }
}

output "consumer" {
  description = "Outputs for Consumer microservice"
  value = {
    "irsa_role" : try(module.consumer_irsa_role[0].iam_role_arn, null)
  }
}

# output "payments" {
#   description = "Outputs for Payments microservice"
#   value = {
#             "irsa_role": try(module.payments_irsa_role[0].iam_role_arn, null)
#           }
# }
