resource "aws_instance" "gitea" {
  ami           = "ami-05c13eab67c5d8861" # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = var.subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.gitea.id]

  user_data = file("${path.module}/userdata.sh")

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

  # Allow access from VS Code VPC (via VPC peering)
  ingress {
    from_port   = var.gitea_port
    to_port     = var.gitea_port
    protocol    = "tcp"
    cidr_blocks = [var.vscode_vpc_cidr]
  }

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
