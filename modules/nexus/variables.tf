# Nexus Module - Variable Definitions
# Input variables for the Nexus module

variable "name_prefix" {
  description = "Name prefix for all Nexus resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Nexus resources will be deployed"
  type        = string
}

variable "keypair" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for Nexus server deployment"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for load balancer"
  type        = list(string)
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS load balancer"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS record"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Nexus DNS record"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Nexus server"
  type        = string
  default     = "t2.medium"
}

variable "tags" {
  description = "Tags to apply to Nexus resources"
  type        = map(string)
  default     = {}
}