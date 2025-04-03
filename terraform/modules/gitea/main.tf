resource "aws_instance" "gitea" {
  ami                         = "ami-05c13eab67c5d8861" # Amazon Linux 2
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.gitea.name
  subnet_id                   = var.subnet_ids[0]
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.gitea.id]

  user_data                   = base64encode(file("${path.module}/userdata.sh"))
  user_data_replace_on_change = true
  tags = {
    Name = var.name
  }
  root_block_device {
    encrypted = true
  }
  monitoring = true

  depends_on = [
    aws_security_group.gitea
  ]
}

# Security Group
resource "aws_security_group" "gitea" {
  name        = "${var.name}-sg"
  description = "Security group for Gitea server"
  vpc_id      = var.vpc_id

  # Allow access from VS Code VPC for Gitea HTTP
  ingress {
    from_port   = var.gitea_port
    to_port     = var.gitea_port
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
  }

  # Allow access from VS Code VPC for Gitea SSH
  ingress {
    from_port   = var.gitea_ssh_port
    to_port     = var.gitea_ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
  }

  # Allow access from EKS cluster (same VPC)
  ingress {
    from_port       = var.gitea_port
    to_port         = var.gitea_port
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "gitea" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_access" {
  name = "ssm-access"
  role = aws_iam_role.gitea.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = ["arn:aws:ssm:*:*:parameter/eks-saas-gitops/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "gitea" {
  name = "${var.name}-profile"
  role = aws_iam_role.gitea.name
}
