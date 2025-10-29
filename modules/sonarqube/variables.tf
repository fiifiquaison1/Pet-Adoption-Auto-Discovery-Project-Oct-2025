variable "name" {
  type        = string
  description = "A name prefix used for tagging and naming resources (e.g., team or environment name)."
  default     = "auto-discovery"
}

variable "vpc" {
  type        = string
  description = "The ID of the VPC where resources like the security group will be created."
  default     = "vpc-0a1b2c3d4e5f6g7h8"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC, used to define ingress/egress rules."
  default     = "10.0.0.0/16"
}

variable "keypair" {
  description = "EC2 Key Pair name for SSH access."
  type        = string
  default     = "fiifi-sonarqube-key"
}

variable "nr_acc_id" {
  description = "New Relic account ID."
  type        = string
  default     = "4638290"
}

variable "nr_key" {
  description = "New Relic license key."
  type        = string
  sensitive   = true
  default     = "NRII-12345-67890-ABCDE"
}

variable "domain_name" {
  description = "The domain name for Route53 and ACM."
  type        = string
  default     = "auto.fiifidevops.site"
}

variable "hosted_zone_id" {
  description = "The hosted zone ID in Route53 where DNS records will be created."
  type        = string
  default     = "Z0EXAMPLE12345"
}

variable "certificate" {
  description = "ARN of the ACM certificate used for HTTPS."
  type        = string
  default     = "arn:aws:acm:eu-west-1:123456789012:certificate/abcd1234-5678-efgh-9101-ijklmnopqrst"
}

variable "subnet_id" {
  description = "Subnet ID for SonarQube EC2 instance."
  type        = string
  default     = "subnet-0abc12345def67890"
}

variable "subnets" {
  description = "List of subnet IDs for ALB or EC2."
  type        = list(string)
  default     = ["subnet-0abc12345def67890", "subnet-0987zyx654wvu321"]
}