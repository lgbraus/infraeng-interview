output "al2023_ami_info" {
  value = {
    id            = data.aws_ami.al2023.id
    name          = data.aws_ami.al2023.name
    creation_date = data.aws_ami.al2023.creation_date
  }
}

output "vpc_info" {
  value = {
    id   = data.aws_vpc.selected.id
    name = data.aws_vpc.selected.tags["Name"]
  }
}

output "subnet_info" {
  value = {
    subnet_ids = data.aws_subnets.private.ids
  }
}

output "iam_role_info" {
  value = {
    role_name = aws_iam_role.ec2.name
  }
}