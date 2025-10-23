# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.pub_sub[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.priv_sub[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.priv_sub[*].cidr_block
}

# Backward compatibility outputs (for existing code)
output "public_subnet_id" {
  description = "ID of the first public subnet (for backward compatibility)"
  value       = aws_subnet.pub_sub[0].id
}

output "public_subnet_cidr" {
  description = "CIDR block of the first public subnet (for backward compatibility)"
  value       = aws_subnet.pub_sub[0].cidr_block
}