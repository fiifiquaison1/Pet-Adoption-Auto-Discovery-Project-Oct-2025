variable "private_key_path" {
  description = "Path to the PEM file for SSH access."
  type        = string
  sensitive   = true
}
variable "vault_token" {
  description = "Vault token for accessing Vault secrets."
  type        = string
  sensitive   = true
}
variable "domain_name" {
  description = "The domain name for Route53 and ACM."
  type        = string
  default     = "fiifiquaison.space"
}

variable "nr_key" {
  description = "New Relic key."
  type        = string
  default     = "F0A064C17F5039AA0F8CEDE59EEE9BD0EDAA504168EA55C7"
}

variable "nr_acc_id" {
  description = "New Relic account ID."
  type        = string
  default     = "6926502"
}

variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "eu-west-3"
}

variable "keypair" {
  description = "EC2 Key Pair name for SSH access."
  type        = string
  default     = "fiifi-pet-adoption-auto-discovery-key"
}


variable "s3_bucket_name" {
  description = "S3 bucket name for storing Ansible scripts and artifacts."
  type        = string
  default     = "auto-discovery-fiifi-86"
}
