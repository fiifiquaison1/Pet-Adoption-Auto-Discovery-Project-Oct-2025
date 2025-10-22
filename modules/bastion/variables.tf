# Bastion Module - Variable Definitions
# Input variables for the Bastion module

variable "name_prefix" {
  description = "Name prefix for all bastion resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where bastion resources will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the bastion ASG"
  type        = list(string)
}

variable "keypair" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "private_key" {
  description = "Private key content for SSH access"
  type        = string
  sensitive   = true
}

variable "nr_license_key" {
  description = "New Relic license key for monitoring"
  type        = string
  sensitive   = true
}

variable "nr_account_id" {
  description = "New Relic account ID for monitoring"
  type        = string
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-3"
}

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t2.micro"
}

variable "tags" {
  description = "Tags to apply to bastion resources"
  type        = map(string)
  default     = {}
}