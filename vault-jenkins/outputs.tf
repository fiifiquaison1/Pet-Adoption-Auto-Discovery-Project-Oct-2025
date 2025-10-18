output "jenkins_public_ip" {
  value = aws_instance.jenkins-server.public_ip
}

output "vault_public_ip" {
  value = aws_instance.vault.public_ip
}

output "jenkins_url" {
  value = "https://jenkins.${var.domain_name}"
}

output "vault_url" {
  value = "https://vault.${var.domain_name}"
}

output "route53_name_servers" {
  value = aws_route53_zone.fiifi_zone.name_servers
  description = "Name servers for the Route53 hosted zone - configure these in your domain registrar"
}