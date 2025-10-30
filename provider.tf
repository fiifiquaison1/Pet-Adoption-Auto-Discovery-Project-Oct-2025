provider "aws" {
  region  = "eu-west-3"
  profile = "default"
}

terraform {
  backend "s3" {
    bucket       = "auto-discovery-fiifi-86"
    use_lockfile = true
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    profile      = "default"
  }
}

provider "vault" {
  address = "https://vault.fiifiquaison.space"
  token   = var.vault_token # or use environment variable VAULT_TOKEN
}
