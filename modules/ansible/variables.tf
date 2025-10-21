# Ansible Module - Variable Definitions
# Input variables for the Ansible automation module

variable "name_prefix" {
  description = "Name prefix for Ansible resources"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID where Ansible server will be deployed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the Ansible server will be deployed"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of the bastion host for SSH access"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file for SSH connections"
  type        = string
  sensitive   = true
}

variable "nexus_server_ip" {
  description = "IP address of the Nexus repository server"
  type        = string
}

variable "new_relic_license_key" {
  description = "New Relic license key for monitoring"
  type        = string
  sensitive   = true
}

variable "new_relic_account_id" {
  description = "New Relic account ID for monitoring setup"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for Ansible server"
  type        = string
  default     = "t2.micro"
}

variable "volume_size" {
  description = "Root volume size in GB for Ansible server"
  type        = number
  default     = 20
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing Ansible scripts and artifacts"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Ansible resources"
  type        = map(string)
  default     = {}
}