variable "name" {
  type        = string
  description = "A name prefix used for tagging and naming resources (e.g., team or environment name)."
}

variable "vpc" {
  type        = string
  description = "The ID of the VPC where resources like the security group will be created."
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC, used to define ingress/egress rules."
}


variable "keypair" {}
variable "subnet_id" {}
variable "certificate" {}
variable "hosted_zone_id" {}
variable "domain_name" {}
variable "subnets" {}