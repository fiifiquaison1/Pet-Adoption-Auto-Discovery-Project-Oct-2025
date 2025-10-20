# Database Module - Output Values
# Output values from the database resources

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.mysql_database.endpoint
}

output "db_security_group_id" {
  description = "Database security group ID"
  value       = aws_security_group.db_sg.id
}