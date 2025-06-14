### Data Sources

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
}

data "aws_vpc" "selected" {
  tags = {
    Name = "my-vpc" # Value hardcoded as only alb and asg name should be passed in to the module
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Name = "*private*"
  }
}

# Data source for the ALB security group
# This should be parameterised and passed in to the module
data "aws_security_group" "alb" {
  tags = {
    Name = "my-alb" # Value hardcoded as only alb and asg name should be passed in to the module
  }
}

### IAM Role for EC2 Instances in Auto Scaling Group

resource "aws_iam_role" "ec2" {
  name = "${var.asg_name}-ec2"

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

  tags = {
    Name      = "${var.asg_name}-ec2"
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.asg_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name      = "${var.asg_name}-ec2-profile"
    Terraform = "true"
  }
}

### Cloudwatch

resource "aws_cloudwatch_log_group" "asg" {
  name              = "/custom/auto-scaling/${var.asg_name}"
  retention_in_days = 30

  tags = {
    Name      = var.asg_name
    Terraform = "true"
  }
}

### Security Groups

# ASG Security Group
resource "aws_security_group" "asg" {
  name        = var.asg_name
  description = "Security group for Auto Scaling Group"
  vpc_id      = data.aws_vpc.selected.id

  tags = {
    Name      = "${var.asg_name}"
    Terraform = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "asg_ingress_http" {
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.asg.id
  referenced_security_group_id = data.aws_security_group.alb.id
  description                  = "Allow HTTP traffic from ALB"
}

resource "aws_vpc_security_group_egress_rule" "asg" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.asg.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow outbound traffic"
}

### Auto Scaling Group

locals {
  user_data = base64encode(
    templatefile("${path.module}/user_data/user_data.sh.tmpl", {
      asg_name = var.asg_name
      }
    )
  )

  user_data_hash = sha1(local.user_data)
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.asg_name}-${local.user_data_hash}-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro" # Value hardcoded as only alb and asg name should be passed in to the module

  vpc_security_group_ids = [aws_security_group.asg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  user_data = local.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.asg_name}-instance"
      Terraform   = "true"
    }
  }

  tags = {
    Name        = var.asg_name
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = var.asg_name
  vpc_zone_identifier       = data.aws_subnets.private.ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = "1" # Value hardcoded as only alb and asg name should be passed in to the module
  max_size         = "3" # Value hardcoded as only alb and asg name should be passed in to the module
  desired_capacity = "2" # Value hardcoded as only alb and asg name should be passed in to the module

  # Maximum amount of time, in seconds, that an instance can be in service
  max_instance_lifetime = 2592000

  termination_policies = ["OldestInstance"]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = true
  }
}