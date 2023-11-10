data "aws_caller_identity" "current" {
}

data "aws_eks_cluster" "eks-saas-gitops" {
  name = "eks-saas-gitops"
}

data "aws_ssm_parameter" "pool_1_consumer_sqs" {
  count  = var.enable_consumer == false ? 1 : 0
  name = "/pooled-1/consumer_sqs"
}

data "aws_ssm_parameter" "pool_1_consumer_ddb" {
  count  = var.enable_consumer == false ? 1 : 0
  name = "/pooled-1/consumer_ddb"
}

# data "aws_ssm_parameter" "pool_1_payments_bucket" {
#   count  = var.enable_payments == false ? 1 : 0
#   name = "/pooled-1/payments_bucket"
# }