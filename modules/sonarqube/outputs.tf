output "sonarqube_instance_id" {
  description = "ID of the SonarQube EC2 instance"
  value       = aws_instance.sonarqube-server.id
}

output "sonarqube_public_ip" {
  description = "Public IP address of the SonarQube instance"
  value       = aws_instance.sonarqube-server.public_ip
}

output "sonarqube_private_ip" {
  description = "Private IP address of the SonarQube instance"
  value       = aws_instance.sonarqube-server.private_ip
}

output "sonarqube_elb_dns" {
  description = "DNS name of the SonarQube load balancer"
  value       = aws_elb.elb_sonarqube.dns_name
}

output "sonarqube_url" {
  description = "URL to access SonarQube"
  value       = "https://sonarqube.${var.domain_name}"
}

output "sonarqube_security_group_id" {
  description = "ID of the SonarQube security group"
  value       = aws_security_group.sonarqube-sg.id
}