output "codecommit_repository_urls" {
  value = module.gitops_saas_infra.codecommit_repository_urls
}

output "ecr_repository_urls" {
  value = module.gitops_saas_infra.ecr_repository_urls
}

output "aws_codecommit_flux_clone_url_ssh" {
  description = "AWS CodeCommit SSH based clone URL"
  value       = module.gitops_saas_infra.aws_codecommit_flux_clone_url_ssh
}

output "ecr_argoworkflow_container" {
  description = "URL for Amazon ECR stored Argo Workflows container"
  value       = module.gitops_saas_infra.ecr_argoworkflow_container
}

output "ecr_helm_chart_url" {
  description = "URL for Amazon ECR stored chart"
  value       = module.gitops_saas_infra.ecr_helm_chart_url
}

output "argo_workflows_bucket_name" {
  description = "Amazon S3 bucket that Argo Workflows will store its artifacts"
  value       = module.gitops_saas_infra.argo_workflows_bucket_name
}

output "argo_workflows_irsa" {
  description = "IAM Role for Argo Workflows Service Account"
  value       = module.gitops_saas_infra.argo_workflows_irsa
}

output "tf_controller_irsa" {
  description = "IAM Role for TF Controller Service Account"
  value       = module.gitops_saas_infra.tf_controller_irsa
}

output "lb_controller_irsa" {
  description = "IAM Role for LB Controller Service Account"
  value       = module.gitops_saas_infra.lb_controller_irsa
}

output "karpenter_irsa" {
  description = "IAM Role for Karpenter Service Account"
  value       = module.gitops_saas_infra.karpenter_irsa
}

output "argo_events_irsa" {
  description = "IAM Role for Argo Events Service Account"
  value       = module.gitops_saas_infra.argo_events_irsa
}