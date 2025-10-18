# Pet Adoption Auto Discovery Project - Variables
# Terraform variables for Vault-Jenkins infrastructure in eu-west-3

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "fiifi-pet-adoption-auto-discovery"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-3"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for ALB."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
  
  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least 1 private subnet is required."
  }
}

# Security Configuration
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
  
  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "At least one CIDR block must be specified for SSH access."
  }
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed for web access (Jenkins UI, Vault UI)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
  
  validation {
    condition     = length(var.allowed_web_cidrs) > 0
    error_message = "At least one CIDR block must be specified for web access."
  }
}

# EC2 Configuration
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition = contains([
      "t3.small", "t3.medium", "t3.large", "t3.xlarge",
      "t2.small", "t2.medium", "t2.large", "t2.xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge"
    ], var.jenkins_instance_type)
    error_message = "Jenkins instance type must be a valid EC2 instance type suitable for Jenkins workloads."
  }
}

variable "vault_instance_type" {
  description = "EC2 instance type for Vault server"
  type        = string
  default     = "t3.small"
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t2.micro", "t2.small", "t2.medium", "t2.large",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.vault_instance_type)
    error_message = "Vault instance type must be a valid EC2 instance type suitable for Vault workloads."
  }
}

variable "jenkins_root_volume_size" {
  description = "Size of the root EBS volume for Jenkins instance (GB)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.jenkins_root_volume_size >= 20 && var.jenkins_root_volume_size <= 1000
    error_message = "Jenkins root volume size must be between 20 and 1000 GB."
  }
}

variable "vault_root_volume_size" {
  description = "Size of the root EBS volume for Vault instance (GB)"
  type        = number
  default     = 20
  
  validation {
    condition     = var.vault_root_volume_size >= 10 && var.vault_root_volume_size <= 1000
    error_message = "Vault root volume size must be between 10 and 1000 GB."
  }
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for the project"
  type        = string
  default     = "fiifiquaison.space"
  
  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format."
  }
}

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins (jenkins.domain_name)"
  type        = string
  default     = "jenkins"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.jenkins_subdomain))
    error_message = "Jenkins subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vault_subdomain" {
  description = "Subdomain for Vault (vault.domain_name)"
  type        = string
  default     = "vault"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.vault_subdomain))
    error_message = "Vault subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "create_route53_zone" {
  description = "Whether to create a Route53 hosted zone for the domain"
  type        = bool
  default     = false
}

# SSH Key Configuration
variable "public_key" {
  description = "Public SSH key for EC2 instance access"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCc0q/t+Stb4ERnuCUFsP7MOUSfS54pljWLQYppxqXizvLE60GdqZVrEaFbxK2PsHYu8dx4uh5BkYnmoxYa7X0xQmO1lspVsOtHhEHucB5ASt9ZAxhOx5qHvwLJrcBGjAHT6ChQVYWJarVnXwNkrbsvoOmkTVWt/+x5SDrkrprH3L+brJSEVrXRXaxbBNhphrWNTDyTOV/cwTCKg5ZJ1sNUdSGfkBLx870U54ASxfWFVydnUbCoX3JR5bK50XVn49ytVJGXDb0kW8phRtaRoXcsPo3u2aHas6uyQzjFV2gzZHy84QJTfRPHBe14jPNBeNB7HzmVmb6W3dxA1M5pEn5ZUi/89Fw8fp18N5b/nTzjk2XonvDk5EwUVREcEh/fq0ioUT2cqp82NQuiMBN/KWUeeLF9cMvC/GRvQJSU7V0TM2HCmKVZz9dbB4Y0ITiOgyPQ0Ja1CDLQRZptpqSyCOhUnxzOubhIBZIjiNRcvTZotua8HC6qn3McsY5NrrDiC3fpdpyPtWj7VG36zI5IW4zbJTaQsba/NKqoJbb9K1vlyiMW7w3U2H9vB3DIoTm0tKrhWd19jTZcBiWQgN+PqakAW0hvXKRWIdAPNfS1aYWtJUt1Sk6Pc3NQHYxDFei5Xbm13fFisov2ek76EttXP1IRDkH79MsRhx8xRmI65Ywk6Q=="
  
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", var.public_key))
    error_message = "Public key must be a valid SSH public key starting with ssh-rsa, ssh-ed25519, or ssh-ecdsa."
  }
}

# Monitoring and Logging
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch log retention period."
  }
}

variable "create_route53_health_checks" {
  description = "Whether to create Route53 health checks"
  type        = bool
  default     = false
}

# Jenkins Configuration
variable "jenkins_admin_username" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
  
  validation {
    condition     = length(var.jenkins_admin_username) >= 3 && length(var.jenkins_admin_username) <= 20
    error_message = "Jenkins admin username must be between 3 and 20 characters."
  }
}

variable "jenkins_plugins" {
  description = "List of Jenkins plugins to install"
  type        = list(string)
  default = [
    "git",
    "github",
    "pipeline-stage-view",
    "docker-workflow",
    "aws-credentials",
    "terraform",
    "kubernetes",
    "nodejs",
    "python",
    "pipeline-utility-steps",
    "build-timeout",
    "credentials-binding",
    "timestamper",
    "ws-cleanup",
    "workflow-aggregator",
    "github-branch-source",
    "pipeline-github-lib",
    "email-ext",
    "mailer"
  ]
}

# Vault Configuration
variable "vault_version" {
  description = "HashiCorp Vault version to install"
  type        = string
  default     = "1.15.2"
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.vault_version))
    error_message = "Vault version must be in semantic version format (e.g., 1.15.2)."
  }
}

variable "vault_ui_enabled" {
  description = "Enable Vault web UI"
  type        = bool
  default     = true
}

variable "vault_log_level" {
  description = "Vault log level"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR"], var.vault_log_level)
    error_message = "Vault log level must be one of: TRACE, DEBUG, INFO, WARN, ERROR."
  }
}

variable "vault_seal_type" {
  description = "Vault seal type (shamir or awskms)"
  type        = string
  default     = "shamir"
  
  validation {
    condition     = contains(["shamir", "awskms"], var.vault_seal_type)
    error_message = "Vault seal type must be either 'shamir' or 'awskms'."
  }
}

# Backup Configuration
variable "enable_automated_backups" {
  description = "Enable automated backups for Vault"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Pet Adoption Specific Configuration
variable "pet_adoption_config" {
  description = "Pet adoption application specific configuration"
  type = object({
    enable_ai_features    = bool
    database_type        = string
    storage_bucket_name  = string
    max_pet_images       = number
  })
  default = {
    enable_ai_features   = true
    database_type       = "postgresql"
    storage_bucket_name = "pet-adoption-storage"
    max_pet_images      = 10
  }
  
  validation {
    condition = contains(["postgresql", "mysql", "mongodb"], var.pet_adoption_config.database_type)
    error_message = "Database type must be one of: postgresql, mysql, mongodb."
  }
  
  validation {
    condition = var.pet_adoption_config.max_pet_images >= 1 && var.pet_adoption_config.max_pet_images <= 50
    error_message = "Max pet images must be between 1 and 50."
  }
}

# Development vs Production Settings
variable "enable_development_features" {
  description = "Enable development-specific features (debug logging, open security groups, etc.)"
  type        = bool
  default     = true
}

variable "enable_ssl_termination" {
  description = "Enable SSL termination at load balancer (requires ACM certificate)"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for SSL termination"
  type        = string
  default     = ""
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Use spot instances for cost optimization (not recommended for production)"
  type        = bool
  default     = false
}

variable "auto_scaling_enabled" {
  description = "Enable auto scaling for Jenkins agents"
  type        = bool
  default     = false
}

# Notification Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email address for infrastructure notifications"
  type        = string
  default     = "admin@example.com"
  
  validation {
    condition     = can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
}