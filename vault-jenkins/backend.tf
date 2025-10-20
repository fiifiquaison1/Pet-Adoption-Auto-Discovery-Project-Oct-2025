# Terraform Backend Configuration
# This file can be used to configure remote state storage
# Uncomment and configure as needed for production use

# terraform {
#   backend "s3" {
#     bucket         = "fiifi-pet-adoption-terraform-state"
#     key            = "prod/terraform.tfstate"
#     region         = "eu-west-3"
#     encrypt        = true
#     dynamodb_table = "fiifi-pet-adoption-terraform-locks"
#   }
# }

# For local development, state is stored locally
# Remember to backup state files before major operations