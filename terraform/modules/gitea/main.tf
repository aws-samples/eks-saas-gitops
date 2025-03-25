resource "aws_instance" "gitea" {
  ami           = "ami-0735c191cf914754d" # Amazon Linux 2, update as needed
  instance_type = "t2.micro"
  subnet_id     = var.public_subnets[0]

  vpc_security_group_ids = [aws_security_group.gitea.id]

  user_data = templatefile("${path.module}/userdata.sh", {
    GITEA_PORT           = var.gitea_port
    GITEA_SSH_PORT       = var.gitea_ssh_port
    GITEA_ADMIN_USER     = var.gitea_admin_user
    GITEA_ADMIN_PASSWORD = var.gitea_admin_password
  })

  tags = {
    Name = var.name
  }
  root_block_device {
    encrypted = true
  }
  monitoring = true
}

resource "aws_security_group" "gitea" {
  name        = "${var.name}-sg"
  description = "Security group for Gitea server"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.gitea_port
    to_port         = var.gitea_port
    protocol        = "tcp"
    security_groups = [var.vscode_security_group_id]
  }

  ingress {
    from_port       = var.gitea_ssh_port
    to_port         = var.gitea_ssh_port
    protocol        = "tcp"
    security_groups = [var.vscode_security_group_id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow EKS nodes to access Gitea
resource "aws_security_group_rule" "eks_to_gitea" {
  type                     = "ingress"
  from_port                = var.gitea_port
  to_port                  = var.gitea_port
  protocol                 = "tcp"
  source_security_group_id = var.eks_security_group_id
  security_group_id        = aws_security_group.gitea.id
}
