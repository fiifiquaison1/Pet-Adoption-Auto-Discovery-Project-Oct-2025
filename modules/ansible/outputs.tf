# Ansible Module - Output Values
# Output values from the Ansible module resources

output "ansible_server_private_ip" {
  description = "Private IP address of the Ansible server"
  value       = aws_instance.ansible_server.private_ip
}

output "ansible_security_group_id" {
  description = "Security group ID for the Ansible server"
  value       = aws_security_group.ansible_sg.id
}

output "ansible_instance_id" {
  description = "EC2 instance ID of the Ansible server"
  value       = aws_instance.ansible_server.id
}

output "ansible_iam_role_arn" {
  description = "ARN of the IAM role attached to the Ansible server"
  value       = aws_iam_role.ansible_role.arn
}

output "ansible_instance_profile_name" {
  description = "Name of the IAM instance profile for the Ansible server"
  value       = aws_iam_instance_profile.ansible_profile.name
}

output "ansible_sg" {
  description = "Ansible security group ID"
  value       = aws_security_group.ansible_sg.id
}