# Fiifi Pet Adoption Auto Discovery Project - Outputs
# Terraform outputs for Vault-Jenkins infrastructure

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.pet_adoption_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.pet_adoption_vpc.cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private_subnets[*].id
}

# Security Group Outputs
output "jenkins_security_group_id" {
  description = "ID of the Jenkins security group"
  value       = aws_security_group.jenkins_sg.id
}

output "vault_security_group_id" {
  description = "ID of the Vault security group"
  value       = aws_security_group.vault_sg.id
}

# EC2 Instance Outputs
output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.id
}

output "jenkins_instance_public_ip" {
  description = "Public IP address of the Jenkins instance"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_instance_private_ip" {
  description = "Private IP address of the Jenkins instance"
  value       = aws_instance.jenkins.private_ip
}

output "vault_instance_id" {
  description = "ID of the Vault EC2 instance"
  value       = aws_instance.vault.id
}

output "vault_instance_private_ip" {
  description = "Private IP address of the Vault instance"
  value       = aws_instance.vault.private_ip
}

# Load Balancer Outputs
output "jenkins_alb_dns_name" {
  description = "DNS name of the Jenkins Application Load Balancer"
  value       = aws_lb.jenkins_alb.dns_name
}

output "jenkins_alb_zone_id" {
  description = "Zone ID of the Jenkins Application Load Balancer"
  value       = aws_lb.jenkins_alb.zone_id
}

output "jenkins_alb_arn" {
  description = "ARN of the Jenkins Application Load Balancer"
  value       = aws_lb.jenkins_alb.arn
}

output "vault_alb_dns_name" {
  description = "DNS name of the Vault Application Load Balancer"
  value       = aws_lb.vault_alb.dns_name
}

output "vault_alb_zone_id" {
  description = "Zone ID of the Vault Application Load Balancer"
  value       = aws_lb.vault_alb.zone_id
}

output "vault_alb_arn" {
  description = "ARN of the Vault Application Load Balancer"
  value       = aws_lb.vault_alb.arn
}

# Access URLs
output "jenkins_url" {
  description = "URL to access Jenkins web interface"
  value       = "http://${aws_lb.jenkins_alb.dns_name}"
}

output "jenkins_domain_url" {
  description = "Domain URL to access Jenkins"
  value       = "http://${var.jenkins_subdomain}.${var.domain_name}"
}

output "jenkins_direct_url" {
  description = "Direct URL to access Jenkins (via public IP)"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "vault_internal_url" {
  description = "Internal URL to access Vault (from within VPC)"
  value       = "http://${aws_instance.vault.private_ip}:8200"
}

output "vault_domain_url" {
  description = "Domain URL to access Vault (internal)"
  value       = "http://${var.vault_subdomain}.${var.domain_name}"
}

output "root_domain_url" {
  description = "Root domain URL"
  value       = "http://${var.domain_name}"
}

# SSH Connection Information
output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins instance"
  value       = "ssh -i ${var.project_name}-key.pem ec2-user@${aws_instance.jenkins.public_ip}"
}

output "vault_ssh_command" {
  description = "SSH command to connect to Vault instance (via Jenkins as bastion)"
  value       = "ssh -i ${var.project_name}-key.pem -o ProxyCommand='ssh -i ${var.project_name}-key.pem -W %h:%p ec2-user@${aws_instance.jenkins.public_ip}' ec2-user@${aws_instance.vault.private_ip}"
}

# IAM Outputs
output "jenkins_iam_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins_role.arn
}

output "vault_iam_role_arn" {
  description = "ARN of the Vault IAM role"
  value       = aws_iam_role.vault_role.arn
}

# Key Pair Output
output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.pet_adoption_key.key_name
}

# CloudWatch Log Groups
output "jenkins_log_group_name" {
  description = "Name of the Jenkins CloudWatch log group"
  value       = aws_cloudwatch_log_group.jenkins_logs.name
}

output "vault_log_group_name" {
  description = "Name of the Vault CloudWatch log group"
  value       = aws_cloudwatch_log_group.vault_logs.name
}

# Route53 Health Check (if created)
output "jenkins_health_check_id" {
  description = "ID of the Jenkins Route53 health check"
  value       = var.create_route53_health_checks ? aws_route53_health_check.jenkins_health[0].id : null
}

# Route53 and Domain Outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.create_route53_zone ? aws_route53_zone.domain[0].zone_id : data.aws_route53_zone.domain[0].zone_id
}

output "route53_name_servers" {
  description = "Route53 hosted zone name servers (if created)"
  value       = var.create_route53_zone ? aws_route53_zone.domain[0].name_servers : null
}

output "domain_configuration" {
  description = "Domain configuration details"
  value = {
    domain_name         = var.domain_name
    jenkins_subdomain   = "${var.jenkins_subdomain}.${var.domain_name}"
    vault_subdomain     = "${var.vault_subdomain}.${var.domain_name}"
    root_domain         = var.domain_name
    www_domain          = "www.${var.domain_name}"
    zone_created        = var.create_route53_zone
  }
}

# Network Configuration
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.pet_adoption_igw.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gw.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

# Summary Information
output "infrastructure_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    project_name        = var.project_name
    environment         = var.environment
    aws_region          = var.aws_region
    domain_name         = var.domain_name
    vpc_id             = aws_vpc.pet_adoption_vpc.id
    jenkins_url        = "http://${var.jenkins_subdomain}.${var.domain_name}"
    vault_internal_url = "http://${var.vault_subdomain}.${var.domain_name}"
    root_domain        = "http://${var.domain_name}"
    public_subnets     = length(aws_subnet.public_subnets)
    private_subnets    = length(aws_subnet.private_subnets)
    deployment_date    = timestamp()
  }
}

# Configuration Files Location
output "configuration_files" {
  description = "Location of important configuration files on instances"
  value = {
    jenkins = {
      home_directory    = "/var/lib/jenkins"
      config_file      = "/var/lib/jenkins/config.xml"
      plugins_directory = "/var/lib/jenkins/plugins"
      workspace        = "/var/lib/jenkins/workspace"
      install_log      = "/var/log/jenkins-install.log"
    }
    vault = {
      config_file      = "/etc/vault.d/vault.hcl"
      data_directory   = "/opt/vault/data"
      keys_directory   = "/opt/vault/keys"
      logs_directory   = "/opt/vault/logs"
      install_log      = "/var/log/vault-install.log"
    }
  }
}

# Important Notes
output "important_notes" {
  description = "Important information about the deployment"
  value = {
    domain_setup = {
      domain_name           = var.domain_name
      jenkins_url          = "http://${var.jenkins_subdomain}.${var.domain_name}"
      vault_url            = "http://${var.vault_subdomain}.${var.domain_name}"
      dns_configuration    = var.create_route53_zone ? "New Route53 zone created" : "Using existing Route53 zone"
      name_servers         = var.create_route53_zone ? "Check route53_name_servers output" : "No changes to DNS"
    }
    access_information = {
      jenkins_initial_password = "Check /var/lib/jenkins/secrets/initialAdminPassword on Jenkins instance"
      vault_root_token        = "Check /opt/vault/keys/root_token on Vault instance (after initialization)"
      vault_unseal_keys       = "Check /opt/vault/keys/unseal_key_* on Vault instance (after initialization)"
      jenkins_role_id         = "Check /opt/vault/keys/jenkins_role_id on Vault instance (for AppRole auth)"
    }
    network_configuration = {
      public_subnets          = length(aws_subnet.public_subnets)
      private_subnets         = length(aws_subnet.private_subnets)
      total_subnets          = length(aws_subnet.public_subnets) + length(aws_subnet.private_subnets)
      ssh_key_required       = "You need the private key corresponding to the public key provided"
      vault_access           = "Vault is in private subnet - access via Jenkins bastion, internal ALB, or VPN"
    }
  }
}

# Monitoring and Logs
output "monitoring_endpoints" {
  description = "Endpoints for monitoring and health checks"
  value = {
    jenkins_health    = "http://${aws_lb.jenkins_alb.dns_name}/login"
    vault_health     = "http://${aws_instance.vault.private_ip}:8200/v1/sys/health"
    jenkins_metrics  = "http://${aws_instance.jenkins.public_ip}:8080/metrics"
    cloudwatch_logs = {
      jenkins = aws_cloudwatch_log_group.jenkins_logs.name
      vault   = aws_cloudwatch_log_group.vault_logs.name
    }
  }
}

# Security Information
output "security_groups" {
  description = "Security group rules summary"
  value = {
    jenkins = {
      id          = aws_security_group.jenkins_sg.id
      name        = aws_security_group.jenkins_sg.name
      description = "SSH (22), Jenkins (8080), Vault communication (8200)"
    }
    vault = {
      id          = aws_security_group.vault_sg.id
      name        = aws_security_group.vault_sg.name
      description = "SSH (22), Vault API (8200), Cluster (8201)"
    }
  }
}

# Backup and Recovery
output "backup_information" {
  description = "Backup and recovery information"
  value = {
    vault_backups = {
      location = "/opt/vault/backups"
      schedule = "Daily at 2 AM"
      retention = "7 days"
    }
    jenkins_backups = {
      recommendation = "Use Jenkins backup plugins or snapshot EBS volumes"
      home_directory = "/var/lib/jenkins"
    }
    ebs_volumes = {
      jenkins_root = "Encrypted GP3 volume"
      vault_root   = "Encrypted GP3 volume"
    }
  }
}