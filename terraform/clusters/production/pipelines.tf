resource "random_uuid" "uuid_2" {}

resource "aws_s3_bucket" "codeartifacts" {
  bucket = "codestack-artifacts-bucket-${random_uuid.uuid_2.result}"
}

module "codebuild_producer_project" {
  source = "../../modules/codebuild"
  vpc_id = module.vpc.vpc_id
  codebuild_project_name = "producer-codebuild"
  private_subnet_list = module.vpc.private_subnets
  bucket_id = aws_s3_bucket.codeartifacts.id
}

module "codepipeline_producer" {
  source = "../../modules/codepipeline"
  pipeline_name = "producer-pipeline"
  codebuild_project = "producer-codebuild"
  repo_name = module.codecommit-producer.name
  bucket_id = aws_s3_bucket.codeartifacts.id
}