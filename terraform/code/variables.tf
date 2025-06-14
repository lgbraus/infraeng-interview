variable "environment" {
  description = "The environment for the Auto Scaling Group (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
  default     = "my-asg"
}

variable "vpc_name" {
  description = "Name of the VPC to use for the Auto Scaling Group"
  type        = string
  default     = "my-vpc"
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "my-alb"
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
  default     = ""
}