# Create a Terraform module with the following requiments for AWS Autoscaling group to run ephemeral EC2 instances:

# The modules input should be:
# 1) Autoscaling group name
# 2) Load balancer URL (Meant to be ALB arn?)

# Module requirements:

# 1) It should run the lastest version of Amazon Linux 2023 every time is launched
# 2) The EC2 instance should be accssible via SSM Session Manager
# 3) The EC2 instance /var/log/messages should be available on Cloud Watch Log
# 4) The auto scalling group should replace the instance every 30 days
# 5) Nginx must be installed and listening to port 80
# 6) The EC2 intances must be hosted on private subnets 

module "aws-asg" {
  source = "./modules/aws-asg"

  asg_name         = "asx-infra-example-asg"
  alb_arn          = aws_lb.alb.arn
  target_group_arn = aws_lb_target_group.asg_tg.arn

  depends_on = [
    aws_security_group.alb
  ]
}


# 6) Create an application load balancer that listen TLS over HTTP and reaches the EC2 instances above on NGINX

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
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids


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