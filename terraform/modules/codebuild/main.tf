resource "aws_iam_role" "codebuild" {
  name = "codebuildrole-${var.codebuild_project_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "example" {
  role = aws_iam_role.codebuild.name
  policy = var.iam_policy
}

resource "aws_security_group" "code_build_default" {
  name        = "${var.codebuild_project_name}-sg"
  description = "Managed by Terraform"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_codebuild_project" "example" {
  name          = var.codebuild_project_name
  description   = var.codebuild_description
  build_timeout = var.build_timeout
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/docker:17.09.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "REPOSITORY_URI"
      value = var.repo_uri
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${var.bucket_id}/${var.codebuild_project_name}-build-log"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  vpc_config {
    vpc_id = var.vpc_id

    subnets = var.private_subnet_list

    security_group_ids = [aws_security_group.code_build_default.id]
  }

  tags = var.tags
}