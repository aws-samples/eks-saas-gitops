data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "gitea" {
  # checkov:skip=CKV_AWS_88: Public IP is required for this instance
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "m5.large"
  iam_instance_profile        = aws_iam_instance_profile.gitea.name
  subnet_id                   = var.subnet_ids[0]
  associate_public_ip_address = true
  ebs_optimized               = true
  monitoring                  = true

  vpc_security_group_ids = [aws_security_group.gitea.id]

  user_data                   = base64encode(file("${path.module}/userdata.sh"))
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = var.name
  }

  depends_on = [
    aws_security_group.gitea
  ]
}

# Security Group
resource "aws_security_group" "gitea" {
  name        = "${var.name}-sg"
  description = "Security group for Gitea server"
  vpc_id      = var.vpc_id

  # Allow SSH access from specific VPC CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
    description = "Allow SSH access from VPC"
  }

  # Allow access from VS Code VPC for Gitea HTTP
  ingress {
    from_port   = var.gitea_port
    to_port     = var.gitea_port
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
    description = "Allow Gitea HTTP access from VS Code VPC"
  }

  # Allow access from VS Code VPC for Gitea SSH
  ingress {
    from_port   = var.gitea_ssh_port
    to_port     = var.gitea_ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
    description = "Allow Gitea SSH access from VS Code VPC"
  }

  # Allow access from EKS cluster (same VPC)
  ingress {
    from_port       = var.gitea_port
    to_port         = var.gitea_port
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
    description     = "Allow Gitea HTTP access from EKS cluster"
  }

  # Allow access from specific IP for Gitea HTTP (if provided)
  dynamic "ingress" {
    for_each = var.allowed_ip != "" ? [1] : []
    content {
      from_port   = var.gitea_port
      to_port     = var.gitea_port
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ip]
      description = "Allow Gitea HTTP access from specific IP"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
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
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = ["arn:aws:ssm:*:*:parameter/eks-saas-gitops/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access"
  role = aws_iam_role.gitea.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# resource "aws_iam_role_policy_attachment" "ssm_instance_connect" {
#   role       = aws_iam_role.gitea.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

resource "aws_iam_instance_profile" "gitea" {
  name = "${var.name}-profile"
  role = aws_iam_role.gitea.name
}
