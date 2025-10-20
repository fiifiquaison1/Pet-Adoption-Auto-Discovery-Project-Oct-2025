variable "domain_name" {
  description = "The domain name for our pet adoption project"
  type        = string
  default     = "fiifiquaison.space"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}