module "gitops_saas_infra" {
  source                    = "../modules/gitops-saas-infra"
  name                      = var.name
  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id                    = module.vpc.vpc_id
  private_subnets           = module.vpc.private_subnets
  public_key_file_path      = var.public_key_file_path # Upload to user created by this module, local executer should have the private key as well
}



################################################################################
# Flux
################################################################################
module "flux_v2" {
  source             = "../modules/flux_cd"
  cluster_endpoint   = module.eks.cluster_endpoint
  ca                 = module.eks.cluster_certificate_authority_data
  token              = data.aws_eks_cluster_auth.this.token
  git_branch         = var.git_branch
  git_url            = module.gitops_saas_infra.aws_codecommit_flux_clone_url_ssh
  kustomization_path = var.kustomization_path
  known_hosts        = var.known_hosts
  private_key_path   = var.private_key_file_path
  public_key_path    = var.public_key_file_path
}