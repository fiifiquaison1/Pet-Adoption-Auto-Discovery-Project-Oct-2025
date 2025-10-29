variable "name_prefix" {
  description = "Prefix for resource names in prod environment."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for prod environment."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for bastion host."
  type        = string
}

variable "ansible_sg_id" {
  description = "Security group ID for ansible host."
  type        = string
}

variable "keypair" {
  description = "Key pair name for EC2 instances."
  type        = string
}

variable "nexus_ip" {
  description = "Nexus server IP address."
  type        = string
}

variable "nr_key" {
  description = "New Relic license key."
  type        = string
}

variable "nr_acc_id" {
  description = "New Relic account ID."
  type        = string
}

variable "private_subnet1" {
  description = "First private subnet ID for ASG."
  type        = string
}

variable "private_subnet2" {
  description = "Second private subnet ID for ASG."
  type        = string
}

variable "public_subnet1" {
  description = "First public subnet ID for ELB."
  type        = string
}

variable "public_subnet2" {
  description = "Second public subnet ID for ELB."
  type        = string
}

variable "acm_cert_arn" {
  description = "ACM certificate ARN for HTTPS listener."
  type        = string
}

variable "domain_name" {
  description = "Domain name for Route53 zone and record."
  type        = string
}
