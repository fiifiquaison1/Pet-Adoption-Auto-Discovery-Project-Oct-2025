# Fiifi Pet Adoption Auto Discovery Project - Outputs
# Essential outputs for accessing and managing the infrastructure

# Access URLs
output "jenkins_url" {
  value       = "https://jenkins.${var.domain_name}"
  description = "Jenkins web interface URL"
}

output "vault_url" {
  value       = "https://vault.${var.domain_name}"
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
