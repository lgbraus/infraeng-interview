### Auto Scaling Group (ASG) Module

module "aws-asg" {
  source = "./modules/aws-asg"

  asg_name         = "asx-infra-example-asg"
  alb_arn          = aws_lb.alb.arn
  target_group_arn = aws_lb_target_group.asg_tg.arn

  depends_on = [
    aws_security_group.alb
  ]
}

### Application Load Balancer (ALB) Configuration

data "aws_vpc" "selected" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Name = "*public*"
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = var.alb_name
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.selected.id

  tags = {
    Name        = var.alb_name
    Terraform   = "true"
    Environment = var.environment
  }

}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http" {
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTP traffic"
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_https" {
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS traffic"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}

# ALB
resource "aws_lb" "alb" {
  name                       = var.alb_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = data.aws_subnets.public.ids
  drop_invalid_header_fields = true
  enable_deletion_protection = true


  tags = {
    Name        = var.alb_name
    Terraform   = "true"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "asg_tg" {
  name     = var.alb_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = var.alb_name
    Terraform   = "true"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "alb_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_tg.arn
  }
}