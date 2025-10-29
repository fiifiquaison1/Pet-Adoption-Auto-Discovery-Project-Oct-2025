output "prod_sg_id" {
  value       = aws_security_group.prod_sg.id
  description = "Security group ID for the prod environment"
}
