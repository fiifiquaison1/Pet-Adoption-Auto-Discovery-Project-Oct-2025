output "stage_sg_id" {
  value       = aws_security_group.stage_sg.id
  description = "Security group ID for the stage environment"
}
