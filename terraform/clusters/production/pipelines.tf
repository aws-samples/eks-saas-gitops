resource "random_uuid" "this" {}

resource "aws_s3_bucket" "codeartifacts" {
  bucket = "codestack-artifacts-bucket-${random_uuid.this.result}"
  force_destroy = true
}

################################################################################
# AWS Codecommit for microsservices
################################################################################
module "codecommit_producer" {
  source          = "lgallard/codecommit/aws"
  version         = "0.2.1"
  default_branch  = "main"
  description     = "Producer microsservice repository"
  repository_name = "producer"
}

module "codecommit_consumer" {
  source          = "lgallard/codecommit/aws"
  version         = "0.2.1"
  default_branch  = "main"
  description     = "Consumer microsservice repository"
  repository_name = "consumer"
}

module "codecommit_payments" {
  source          = "lgallard/codecommit/aws"
  version         = "0.2.1"
  default_branch  = "main"
  description     = "Payments microsservice repository"
  repository_name = "payments"
}

################################################################################
# Producer CI
################################################################################
module "codebuild_producer_project" {
  source                 = "../../modules/codebuild"
  vpc_id                 = module.vpc.vpc_id
  codebuild_project_name = "producer-codebuild"
  private_subnet_list    = module.vpc.private_subnets
  bucket_id              = aws_s3_bucket.codeartifacts.id
  repo_uri               = aws_ecr_repository.producer_container.repository_url # Interpolated to buildspec.yml
}

module "codepipeline_producer" {
  source            = "../../modules/codepipeline"
  pipeline_name     = "producer-pipeline"
  codebuild_project = "producer-codebuild"
  repo_name         = module.codecommit_producer.name
  bucket_id         = aws_s3_bucket.codeartifacts.id
}

################################################################################
# Consumer CI
################################################################################
module "codebuild_consumer_project" {
  source                 = "../../modules/codebuild"
  vpc_id                 = module.vpc.vpc_id
  codebuild_project_name = "consumer-codebuild"
  private_subnet_list    = module.vpc.private_subnets
  bucket_id              = aws_s3_bucket.codeartifacts.id
  repo_uri               = aws_ecr_repository.consumer_container.repository_url # Interpolated to buildspec.yml
}

module "codepipeline_consumer" {
  source            = "../../modules/codepipeline"
  pipeline_name     = "consumer-pipeline"
  codebuild_project = "consumer-codebuild"
  repo_name         = module.codecommit_consumer.name
  bucket_id         = aws_s3_bucket.codeartifacts.id
}

###############################################################################
# Payments CI
################################################################################
module "codebuild_payments_project" {
  source                 = "../../modules/codebuild"
  vpc_id                 = module.vpc.vpc_id
  codebuild_project_name = "payments-codebuild"
  private_subnet_list    = module.vpc.private_subnets
  bucket_id              = aws_s3_bucket.codeartifacts.id
  repo_uri               = aws_ecr_repository.payments_container.repository_url # Interpolated to buildspec.yml
}

module "codepipeline_payments" {
  source            = "../../modules/codepipeline"
  pipeline_name     = "payments-pipeline"
  codebuild_project = "payments-codebuild"
  repo_name         = module.codecommit_payments.name
  bucket_id         = aws_s3_bucket.codeartifacts.id
}