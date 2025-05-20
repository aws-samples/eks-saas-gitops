output "aws_region" {
  value = data.aws_region.current.name
}

output "cluster_endpoint" {
  description = "Amazon EKS Cluster Endpoint address"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The Amazon Resource Name (ARN) of the cluster, use"
  value       = module.eks.cluster_name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "gitea_url" {
  description = "URL of the Gitea Instance"
  value       = "http://${module.gitea.public_ip}:3000"
}

################################################################################
# SaaS GitOps Infrastructure Outputs
################################################################################

output "karpenter_node_role_arn" {
  description = "Karpenter Node IAM Role ARN"
  value       = module.gitops_saas_infra.karpenter_node_role_arn
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

output "argo_workflows_irsa" {
  description = "IAM Role for Argo Workflows Service Account"
  value       = module.gitops_saas_infra.argo_workflows_irsa
}

output "argo_events_irsa" {
  description = "IAM Role for Argo Events Service Account"
  value       = module.gitops_saas_infra.argo_events_irsa
}

output "argo_workflows_bucket_name" {
  description = "Amazon S3 bucket that Argo Workflows will store its artifacts"
  value       = module.gitops_saas_infra.argo_workflows_bucket_name
}

output "ecr_helm_chart_url" {
  description = "URL for Amazon ECR stored tenant helm chart"
  value       = module.gitops_saas_infra.ecr_helm_chart_url
}

output "ecr_helm_chart_url_application" {
  description = "URL for Amazon ECR stored application helm chart"
  value       = module.gitops_saas_infra.ecr_helm_chart_url_application
}

output "ecr_argoworkflow_container" {
  description = "URL for Amazon ECR stored Argo Workflows container"
  value       = module.gitops_saas_infra.ecr_argoworkflow_container
}

output "argoworkflows_onboarding_queue_url" {
  description = "URL for the ArgoWorkflows Onboarding SQS Queue"
  value       = module.gitops_saas_infra.argoworkflows_onboarding_queue_url
}

output "argoworkflows_offboarding_queue_url" {
  description = "URL for the ArgoWorkflows Offboarding SQS Queue"
  value       = module.gitops_saas_infra.argoworkflows_offboarding_queue_url
}

output "argoworkflows_deployment_queue_url" {
  description = "URL for the ArgoWorkflows Deployment SQS Queue"
  value       = module.gitops_saas_infra.argoworkflows_deployment_queue_url
}

output "ecr_repositories" {
  description = "ECR Repository URLs for microservices"
  value       = module.gitops_saas_infra.ecr_repository_urls
}

output "gitea_private_ip" {
  description = "Private IP of the Gitea server"
  value       = module.gitea.private_ip
}

output "gitea_public_ip" {
  description = "Public IP of the Gitea server"
  value       = module.gitea.public_ip
}

output "flux_namespace" {
  description = "Namespace where Flux is installed"
  value       = module.flux_v2.flux_namespace
}
