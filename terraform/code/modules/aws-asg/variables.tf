# variable "environment" {
#   description = "The environment for the Auto Scaling Group (e.g., dev, staging, prod)"
#   type        = string
#   default     = "dev"
# }

variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
  default     = "my-asg"
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the Target Group for the Auto Scaling Group"
  type        = string
  default     = ""
}

# variable "vpc_name" {
#   description = "Name of the VPC to use for the Auto Scaling Group"
#   type        = string
#   default     = "my-vpc"
# }

# variable "instance_type" {
#   description = "EC2 instance type"
#   type        = string
#   default     = "t3.micro"

# }

# variable "instance_min_count" {
#   description = "Minimum number of instances in the Auto Scaling Group"
#   type        = number
#   default     = 1
# }

# variable "instance_max_count" {
#   description = "Maximum number of instances in the Auto Scaling Group"
#   type        = number
#   default     = 3
# }

# variable "instance_desired_count" {
#   description = "Desired number of instances in the Auto Scaling Group"
#   type        = number
#   default     = 2
# }

# variable "alb_name" {
#   description = "Name of the Application Load Balancer"
#   type        = string
#   default     = "my-alb"
# }