variable "name_prefix" {
  description = "Name prefix for resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the stage environment."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion host."
  type        = string
}

variable "ansible_sg_id" {
  description = "Security group ID for the ansible host."
  type        = string
}

variable "keypair" {
  description = "EC2 Key Pair name for SSH access."
  type        = string
}

variable "nexus_ip" {
  description = "Nexus server IP address."
  type        = string
}

variable "nr_key" {
  description = "New Relic key."
  type        = string
}

variable "nr_acc_id" {
  description = "New Relic account ID."
  type        = string
}

variable "private_subnet1" {
  description = "First private subnet ID."
  type        = string
}

variable "private_subnet2" {
  description = "Second private subnet ID."
  type        = string
}

variable "public_subnet1" {
  description = "First public subnet ID."
  type        = string
}

variable "public_subnet2" {
  description = "Second public subnet ID."
  type        = string
}

variable "acm_cert_arn" {
  description = "ACM certificate ARN for HTTPS listener."
  type        = string
}

variable "domain_name" {
  description = "Domain name for Route53 and ALB."
  type        = string
}
