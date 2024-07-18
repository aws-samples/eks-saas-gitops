output "karpenter_node_role_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "tf_controller_irsa" {
  description = "IAM Role for TF Controller Service Account"
  value = module.tf_controller_irsa_role.iam_role_arn
}

output "lb_controller_irsa" {
  description = "IAM Role for LB Controller Service Account"
  value = module.lb_controller_irsa.iam_role_arn
}

output "karpenter_irsa" {
  description = "IAM Role for Karpenter Service Account"
  value = module.karpenter_irsa_role.iam_role_arn
}

output "argo_workflows_irsa" {
  description = "IAM Role for Argo Workflows Service Account"
  value       = module.argo_workflows_eks_role.iam_role_arn
}

output "argo_events_irsa" {
  description = "IAM Role for Argo Events Service Account"
  value       = module.argo_events_eks_role.iam_role_arn
}

output "argo_workflows_bucket_name" {
  description = "Amazon S3 bucket that Argo Workflows will store its artifacts"
  value       = aws_s3_bucket.argo_artifacts.id
}

output "ecr_helm_chart_url" {
  description = "URL for Amazon ECR stored chart"
  value       = aws_ecr_repository.tenant_helm_chart.repository_url
}

output "ecr_helm_chart_url_application" {
  description = "URL for Amazon ECR stored chart"
  value       = aws_ecr_repository.application_helm_chart.repository_url
}

output "ecr_argoworkflow_container" {
  description = "URL for Amazon ECR stored Argo Workflows container"
  value       = aws_ecr_repository.argoworkflow_container.repository_url
}

output "argoworkflows_onboarding_queue_url" {
  description = "URL for the ArgoWokflows Onboarding SQS Queue"
  value       = aws_sqs_queue.argoworkflows_onboarding_queue.url
}

output "argoworkflows_offboarding_queue_url" {
  description = "URL for the ArgoWokflows Onboarding SQS Queue"
  value       = aws_sqs_queue.argoworkflows_offboarding_queue.url
}

output "argoworkflows_deployment_queue_url" {
  description = "URL for the ArgoWokflows Onboarding SQS Queue"
  value       = aws_sqs_queue.argoworkflows_deployment_queue.url
}

##################
# Flux Repo
##################
output "aws_codecommit_flux_clone_url_http" {
  description = "AWS CodeCommit HTTP based clone URL"
  value       = module.codecommit_flux.clone_url_http
}

output "aws_codecommit_flux_clone_url_ssh" {
  description = "AWS CodeCommit SSH based clone URL including the SSH public key ID for the Flux repository."
  value = replace(
    module.codecommit_flux.clone_url_ssh,
    "ssh://",
    format("ssh://%s@", aws_iam_user_ssh_key.codecommit_user.ssh_public_key_id)
  )
}


output "ssh_public_key_id" {
  description = "The SSH public key ID for the CodeCommit user"
  value       = aws_iam_user_ssh_key.codecommit_user.ssh_public_key_id
}

##################
# Applications
##################
output "codecommit_repository_urls" {
  value = {
    for key, repo in module.codecommit : 
    key => replace(
      repo.clone_url_ssh,
      "ssh://",
      format("ssh://%s@", aws_iam_user_ssh_key.codecommit_user.ssh_public_key_id)
    )
  }
  description = "The SSH clone URLs of the CodeCommit repositories, including the SSH public key ID."
}




output "ecr_repository_urls" {
  value = { for key, repo in aws_ecr_repository.microservice_container : key => repo.repository_url }
  description = "The URLs of the ECR repositories."
}

