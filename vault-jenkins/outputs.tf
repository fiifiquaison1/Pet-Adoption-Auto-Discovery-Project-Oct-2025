# Fiifi Pet Adoption Auto Discovery Project - Outputs
# Essential outputs for accessing and managing the infrastructure

# Access URLs
output "jenkins_url" {
  value       = "https://jenkins.fiifiquaison.space"
  description = "Jenkins web interface URL"
}

output "vault_url" {
  value       = "https://vault.fiifiquaison.space"
  description = "Vault web interface URL"
}

# Public IPs (for troubleshooting)
output "jenkins_public_ip" {
  value       = aws_instance.jenkins-server.public_ip
  description = "Jenkins server public IP"
}

output "vault_public_ip" {
  value       = aws_instance.vault.public_ip
  description = "Vault server public IP"
}

# SSL Certificate ARNs
output "jenkins_certificate_arn" {
  description = "ARN of the validated Jenkins certificate"
  value       = aws_acm_certificate_validation.jenkins_cert_validation.certificate_arn
}

output "vault_certificate_arn" {
  description = "ARN of the validated Vault certificate"
  value       = aws_acm_certificate_validation.vault_cert_validation.certificate_arn
}
