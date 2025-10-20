# create aws provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Fiifi-Pet-Adoption-Auto-Discovery"
      Environment = var.environment
      Owner       = "fiifiquaison1"
      ManagedBy   = "Terraform"
      CreatedDate = "2025-10-18"
    }
  }
}

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # backend "s3" {
  #   bucket       = "pet-adoption-state-bucket-1"
  #   use_lockfile = true
  #   key          = "vault-jenkins/terraform.tfstate"
  #   region       = "eu-west-1"
  #   encrypt      = true
  #   profile      = "pet-adoption"
  # }
}