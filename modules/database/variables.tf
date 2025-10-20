# Database Module - Variable Definitions
# Input variables for the database module

variable "name_prefix" {
  description = "Name prefix for database resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for database deployment"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs that can access the database"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to database resources"
  type        = map(string)
  default     = {}
}