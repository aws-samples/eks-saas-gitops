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
  value = module.eks.cluster_endpoint
}

output "cluster_primary_security_group_id" {
  value = module.eks.cluster_primary_security_group_id
}

################################################################################
# Karpenter
################################################################################
output "karpenter_irsa" {
  value = module.karpenter_irsa_role.iam_role_arn
}

output "karpenter_instance_profile" {
  value = aws_iam_instance_profile.karpenter_instance_profile.name
}

################################################################################
# Argo Workflows
################################################################################
output "argo_workflows_irsa" {
  value = module.argo_workflows_eks_role.iam_role_arn
}

output "argo_workflows_bucket_name" {
  value = aws_s3_bucket.argo-artifacts.id
}

################
# LB Controller
################

output "lb_controller_irsa" {
  value = module.lb-controller-irsa.iam_role_arn
}

##################
# ECR Helm Chart
##################

output "ecr_helm_chart_url" {
  value = aws_ecr_repository.tenant_helm_chart.repository_url
}

output "ecr_argoworkflow_container" {
  value = aws_ecr_repository.argoworkflow_container.repository_url
}

output "ecr_consumer_container" {
  value = aws_ecr_repository.consumer_container.repository_url
}

output "ecr_producer_container" {
  value = aws_ecr_repository.producer_container.repository_url
}

#####################
# S3 TENANT STATE TF
#####################
output "tenant_terraform_state_bucket_name" {
  value = aws_s3_bucket.tenant-terraform-state-bucket.id
}

#####################
# Code Commit Outputs
#####################

output "aws_codecommit_clone_url_http" {
  value = module.codecommit-flux.clone_url_http
}

output "aws_codecommit_clone_url_ssh" {
  value = module.codecommit-flux.clone_url_ssh
}