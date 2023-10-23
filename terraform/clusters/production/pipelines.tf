module "codebuild_producer_project" {
  source = "../../modules/codebuild"
  vpc_id = module.vpc.vpc_id
  codebuild_project_name = "producer-codebuild"
  private_subnet_list = module.vpc.private_subnets
  bucket_id = aws_s3_bucket.tenant-terraform-state-bucket.id
}