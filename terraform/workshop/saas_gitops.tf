module "gitops_saas_infra" {
  source                    = "../modules/gitops-saas-infra"
  name                      = var.name
  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id                    = module.vpc.vpc_id
  private_subnets           = module.vpc.private_subnets

  depends_on = [data.aws_availability_zones.available, data.aws_caller_identity.current, data.aws_region.current]
}

# resource "null_resource" "execute_templating_script" {
#   provisioner "local-exec" {
#     command = "bash ${path.module}/templating.sh ${var.clone_directory} "
#   }

#   depends_on = [module.gitops_saas_infra]
# }

# Create ConfigMap with important outputs from gitops_saas_infra module
resource "kubernetes_config_map" "saas_infra_outputs" {
  metadata {
    name      = "saas-infra-outputs"
    namespace = "flux-system"
  }

  data = {
    # Cluster information
    cluster_endpoint             = module.eks.cluster_endpoint
    cluster_name                 = module.eks.cluster_name
    aws_region                   = var.aws_region
    account_id                   = data.aws_caller_identity.current.account_id
    
    # IAM roles
    karpenter_node_role_arn      = module.gitops_saas_infra.karpenter_node_role_arn
    tf_controller_irsa           = module.gitops_saas_infra.tf_controller_irsa
    lb_controller_irsa           = module.gitops_saas_infra.lb_controller_irsa
    karpenter_irsa               = module.gitops_saas_infra.karpenter_irsa
    argo_workflows_irsa          = module.gitops_saas_infra.argo_workflows_irsa
    argo_events_irsa             = module.gitops_saas_infra.argo_events_irsa
    
    # S3 buckets
    argo_workflows_bucket_name   = module.gitops_saas_infra.argo_workflows_bucket_name
    
    # Helm chart ECR repositories
    ecr_helm_chart_url           = module.gitops_saas_infra.ecr_helm_chart_url
    ecr_helm_chart_url_application = module.gitops_saas_infra.ecr_helm_chart_url_application
    ecr_argoworkflow_container   = module.gitops_saas_infra.ecr_argoworkflow_container
    ecr_helm_chart_url_base      = join("/", slice(split("/", module.gitops_saas_infra.ecr_helm_chart_url), 0, length(split("/", module.gitops_saas_infra.ecr_helm_chart_url)) - 1))
    
    # SQS queues
    argoworkflows_onboarding_queue_url  = module.gitops_saas_infra.argoworkflows_onboarding_queue_url
    argoworkflows_offboarding_queue_url = module.gitops_saas_infra.argoworkflows_offboarding_queue_url
    argoworkflows_deployment_queue_url  = module.gitops_saas_infra.argoworkflows_deployment_queue_url
    
    # Individual ECR repositories for microservices
    ecr_producer_url             = lookup(module.gitops_saas_infra.ecr_repository_urls, "producer", "")
    ecr_consumer_url             = lookup(module.gitops_saas_infra.ecr_repository_urls, "consumer", "")
    ecr_payments_url             = lookup(module.gitops_saas_infra.ecr_repository_urls, "payments", "")
    ecr_onboarding_service_url   = lookup(module.gitops_saas_infra.ecr_repository_urls, "onboarding_service", "")
    
    # Gitea information
    gitea_url                    = "http://${module.gitea.private_ip}:3000"
  }

  depends_on = [module.flux_v2, module.gitops_saas_infra]
}


################################################################################
# Flux
################################################################################

# Get Gitea Flux token from SSM Parameter Store
data "aws_ssm_parameter" "gitea_flux_token" {
  name            = "/eks-saas-gitops/gitea-flux-token"
  with_decryption = true
}

module "flux_v2" {
  source                   = "../modules/flux_cd"
  cluster_endpoint         = module.eks.cluster_endpoint
  ca                       = module.eks.cluster_certificate_authority_data
  token                    = data.aws_eks_cluster_auth.this.token
  git_branch               = var.git_branch
  kustomization_path       = var.kustomization_path
  flux2_sync_secret_values = var.flux2_sync_secret_values
  image_automation_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn
  image_reflection_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn
  
  # Gitea configuration for Flux
  gitea_repo_url = "http://${module.gitea.private_ip}:3000/admin/eks-saas-gitops.git"
  gitea_username = "admin"
  gitea_token    = data.aws_ssm_parameter.gitea_flux_token.value
}
