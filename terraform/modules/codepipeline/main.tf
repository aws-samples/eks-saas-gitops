################################################################################
# IAM Roles
################################################################################
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipelinerole-${var.pipeline_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy-${var.pipeline_name}"
  role = aws_iam_role.codepipeline_role.id

  policy = var.iam_policy
}

################################################################################
# AWS Codepipeline
################################################################################
resource "aws_codepipeline" "pipeline" {
  name     = var.pipeline_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = var.bucket_id
    type     = "S3"
  }
  # TODO - change provider to gitea
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName = var.repo_name //MUST BE the name of the your codecommit repo
        BranchName     = var.branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["ImageArtifact", "DefinitionArtifact"]

      configuration = {
        ProjectName = var.codebuild_project
      }
    }
  }
}
