# Bastion Module - Output Values
# Output values for the Bastion module

# Data source to get running bastion instances
data "aws_instances" "bastion-instances" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-bastion-asg"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_autoscaling_group.bastion-asg]
}

# Output: Bastion Security Group ID
output "bastion_sg_id" {
  description = "ID of the bastion host security group"
  value       = aws_security_group.bastion-sg.id
}

# Output: Bastion Public IP
output "bastion_public_ip" {
  description = "Public IP address of the running bastion instance"
  value       = length(data.aws_instances.bastion-instances.public_ips) > 0 ? data.aws_instances.bastion-instances.public_ips[0] : ""
}

# Output: Auto Scaling Group Name
output "bastion_asg_name" {
  description = "Name of the bastion auto scaling group"
  value       = aws_autoscaling_group.bastion-asg.name
}