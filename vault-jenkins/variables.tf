# Fiifi Pet Adoption Auto Discovery Project - Variables
# Core configuration variables for Jenkins and Vault infrastructure

variable "domain_name" {
  description = "Domain name for pet adoption project"
  type        = string
  default     = "fiifiquaison.space"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}