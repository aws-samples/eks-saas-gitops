resource "aws_instance" "gitea" {
  ami                         = "ami-05c13eab67c5d8861" # Amazon Linux 2
  instance_type               = "t2.micro"
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

################################################################################
# ALB for Gitea Instance
################################################################################
# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for Gitea ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "gitea" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "gitea" {
  name     = "${var.name}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_instance.gitea]

}

# Listener
resource "aws_lb_listener" "gitea" {
  load_balancer_arn = aws_lb.gitea.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitea.arn
  }
}

# Attach the Gitea instance to the target group
resource "aws_lb_target_group_attachment" "gitea" {
  target_group_arn = aws_lb_target_group.gitea.arn
  target_id        = aws_instance.gitea.id
  port             = 3000

  depends_on = [
    aws_instance.gitea,
    aws_lb_target_group.gitea,
  ]
}

# Update Gitea security group to allow traffic from ALB
resource "aws_security_group_rule" "gitea_from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.gitea.id
}

output "alb_dns_name" {
  value = aws_lb.gitea.dns_name
}
