# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

}
terraform {
  backend "s3" {
    bucket  = "auto-discovery-fiifi-86"
    key     = "vault-jenkins/terraform.tfstate"
    region  = "eu-west-3"
    encrypt = true
  }
}