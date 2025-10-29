# EC2 Instance Outputs
output "sonarqube_instance_id" {
  description = "The ID of the SonarQube EC2 instance"
  value       = aws_instance.sonarqube.id
}

output "sonarqube_public_ip" {
  description = "The public IP address of the SonarQube instance"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_private_ip" {
  description = "The private IP address of the SonarQube instance"
  value       = aws_instance.sonarqube.private_ip
}

# Load Balancer Outputs
output "sonarqube_alb_dns" {
  description = "The DNS name of the SonarQube application load balancer"
  value       = aws_lb.sonar_alb.dns_name
}

# DNS Record & Access URL
output "sonarqube_url" {
  description = "Public HTTPS URL to access SonarQube via Route53 + ACM"
  value       = "https://sonar.${var.domain_name}"
}

output "sonarqube_dns_record" {
  description = "Fully qualified DNS record created in Route53"
  value       = aws_route53_record.sonarqube_dns.fqdn
}

# Security Group
output "sonarqube_security_group_id" {
  description = "The ID of the SonarQube EC2 security group"
  value       = aws_security_group.sonarqube_sg.id
}

# ACM & Domain Information
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used for HTTPS"
  value       = aws_acm_certificate.sonar_cert.arn
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.hosted_zone_id
}

output "domain_name" {
  description = "Domain name used for SonarQube"
  value       = var.domain_name
}

# New Relic Integration (Optional Debug)
output "newrelic_account_id" {
  description = "New Relic account ID (for reference only)"
  value       = var.nr_acc_id
  sensitive   = true
}

output "newrelic_license_key" {
  description = "New Relic license key (sensitive)"
  value       = var.nr_key
  sensitive   = true
}