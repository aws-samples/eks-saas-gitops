module "gitops_saas_infra" {
  source                    = "../modules/gitops-saas-infra"
  name                      = var.name
  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id                    = module.vpc.vpc_id
  private_subnets           = module.vpc.private_subnets
  public_key_file_path      = var.public_key_file_path # Upload to user created by this module, local executer should have the private key as well

  depends_on = [data.aws_availability_zones.available, data.aws_caller_identity.current, data.aws_region.current]
}

resource "null_resource" "execute_templating_script" {
  provisioner "local-exec" {
    command = "bash ${path.module}/templating.sh ${var.clone_directory} "
  }

  depends_on = [module.gitops_saas_infra]
}


################################################################################
# Flux
################################################################################
module "flux_v2" {
  source                   = "../modules/flux_cd"
  cluster_endpoint         = module.eks.cluster_endpoint
  ca                       = module.eks.cluster_certificate_authority_data
  token                    = data.aws_eks_cluster_auth.this.token
  git_branch               = var.git_branch
  git_url                  = module.gitops_saas_infra.aws_codecommit_flux_clone_url_ssh
  kustomization_path       = var.kustomization_path
  flux2_sync_secret_values = var.flux2_sync_secret_values
  image_automation_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn
  image_reflection_controller_sa_annotations = module.image_automation_irsa_role.iam_role_arn
}
