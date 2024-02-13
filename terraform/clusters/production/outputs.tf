################################################################################
# VPC
################################################################################
output "aws_vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_region" {
  value = var.aws_region
}

################################################################################
# Cluster
################################################################################
output "cluster_iam_role_name" {
  value = module.eks.cluster_iam_role_name
}

output "cluster_name" {
  description = "The Amazon Resource Name (ARN) of the cluster, use"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Amazon EKS Cluster Endpoint address"
  value       = module.eks.cluster_endpoint
}

output "cluster_primary_security_group_id" {
  description = "Amazon EKS Cluster Security Group ID"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Karpenter
################################################################################
output "karpenter_irsa" {
  description = "IAM Role for Karpenter Service Account"
  value       = module.karpenter_irsa_role.iam_role_arn
}

output "karpenter_instance_profile" {
  description = "Instance profile that will be used on Karpenter provisioned instances"
  value       = aws_iam_instance_profile.karpenter_instance_profile.name
}

################################################################################
# Argo Workflows
################################################################################
output "argo_workflows_irsa" {
  description = "IAM Role for Argo Workflows Service Account"
  value       = module.argo_workflows_eks_role.iam_role_arn
}

output "argo_workflows_bucket_name" {
  description = "Amazon S3 bucket that Argo Workflows will store its artifacts"
  value       = aws_s3_bucket.argo_artifacts.id
}

output "argo_workflows_onboarding_sqs_url" {
  description = "Amazon SQS queue URL for Onboarding"
  value       = aws_sqs_queue.argoworkflows_onboarding_queue.url
}

output "argo_workflows_deployment_sqs_url" {
  description = "Amazon SQS queue URL for Deployment"
  value       = aws_sqs_queue.argoworkflows_deployment_queue.url
}

output "argo_events_irsa" {
  description = "IAM Role for Argo Events Service Account"
  value       = module.argo_events_eks_role.iam_role_arn
}

################
# LB Controller
################
output "lb_controller_irsa" {
  description = "IAM Role for Load Balancer Controller Service Account"
  value       = module.lb_controller_irsa.iam_role_arn
}

##################
# ECR Helm Chart
##################
output "ecr_helm_chart_url" {
  description = "URL for Amazon ECR stored chart"
  value       = aws_ecr_repository.tenant_helm_chart.repository_url
}

output "ecr_argoworkflow_container" {
  description = "URL for Amazon ECR stored Argo Workflows container"
  value       = aws_ecr_repository.argoworkflow_container.repository_url
}

output "ecr_consumer_container" {
  description = "URL for Amazon ECR stored Consumer container"
  value       = aws_ecr_repository.consumer_container.repository_url

}

output "ecr_producer_container" {
  description = "URL for Amazon ECR stored Producer container"
  value       = aws_ecr_repository.producer_container.repository_url
}

output "ecr_payments_container" {
  description = "URL for Amazon ECR stored Payments container"
  value       = aws_ecr_repository.payments_container.repository_url
}

#####################
# S3 TENANT STATE TF
#####################
output "tenant_terraform_state_bucket_name" {
  description = "Amazon S3 bucket name for Terraform state"
  value       = aws_s3_bucket.tenant_terraform_state_bucket.id
}

#####################
# Code Commit Outputs
#####################
output "aws_codecommit_clone_url_http" {
  description = "AWS CodeCommit HTTP based clone URL"
  value       = module.codecommit_flux.clone_url_http
}

output "aws_codecommit_clone_url_ssh" {
  description = "AWS CodeCommit SSH based clone URL"
  value       = module.codecommit_flux.clone_url_ssh
}

# Producer microsservice Clone URL
output "aws_codecommit_producer_clone_url_http" {
  description = "AWS CodeCommit Producer repo HTTP based clone URL"
  value       = module.codecommit_producer.clone_url_http
}

output "aws_codecommit_producer_clone_url_ssh" {
  description = "AWS CodeCommit Producer repo SSH based clone URL"
  value       = module.codecommit_producer.clone_url_ssh
}

# Consumer microsservice Clone URL
output "aws_codecommit_consumer_clone_url_http" {
  description = "AWS CodeCommit Consumer repo HTTP based clone URL"
  value       = module.codecommit_consumer.clone_url_http
}

output "aws_codecommit_consumer_clone_url_ssh" {
  description = "AWS CodeCommit Consumer repo SSH based clone URL"
  value       = module.codecommit_consumer.clone_url_ssh
}

# Payments microsservice Clone URL

output "aws_codecommit_payments_clone_url_http" {
  description = "AWS CodeCommit payments repo HTTP based clone URL"
  value       = module.codecommit_payments.clone_url_http
}

output "aws_codecommit_payments_clone_url_ssh" {
  description = "AWS CodeCommit payments repo SSH based clone URL"
  value       = module.codecommit_payments.clone_url_ssh
}

output "tf_controller_irsa_role_arn" {
  description = "AWS CodeCommit payments repo SSH based clone URL"
  value       = module.tf_controller_irsa_role.iam_role_arn
}