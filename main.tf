resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"
  tags = {
    Name    = "Wildcard ACM for fiifiquaison.space"
    Service = "All Subdomains"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation record for wildcard ACM
resource "aws_route53_record" "wildcard_validation" {
  zone_id = data.aws_route53_zone.zone.id
  name    = tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_type
  ttl     = 300
  records = [tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_value]
  allow_overwrite = true
}

# Validate wildcard ACM certificate
resource "aws_acm_certificate_validation" "wildcard_validation" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [aws_route53_record.wildcard_validation.fqdn]
  timeouts {
    create = "30m"
  }
  depends_on = [aws_route53_record.wildcard_validation]
}
locals {
  name_prefix = "fiifi-pet-adoption-auto-discovery"
}

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}


module "vpc" {
  source                = "./modules/vpc"
  name_prefix           = local.name_prefix
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones    = ["eu-west-3a", "eu-west-3b"]
  tags                  = {}
}

module "bastion" {
  source            = "./modules/bastion"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  keypair           = var.keypair
  nr_license_key    = var.nr_key
  nr_account_id     = var.nr_acc_id
  region            = var.aws_region
  instance_type     = "t2.micro"
  tags              = {}
}

module "ansible" {
  source                    = "./modules/ansible"
  name_prefix               = local.name_prefix
  key_pair_name             = var.keypair
  private_subnet_id         = module.vpc.private_subnet_ids[0]
  vpc_id                    = module.vpc.vpc_id
  bastion_security_group_id = module.bastion.bastion_sg
  nexus_server_ip           = module.nexus.nexus_ip
  new_relic_license_key     = var.nr_key
  new_relic_account_id      = var.nr_acc_id
  instance_type             = "t2.micro"
  volume_size               = 20
  s3_bucket_name            = var.s3_bucket_name
  tags                      = {}
}

module "database" {
  source              = "./modules/database"
  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids  = [module.bastion.bastion_sg, module.stage_env.stage_sg_id, module.prod_env.prod_sg_id]
  tags                = {}
  vault_token         = var.vault_token
}

module "sonarqube" {
  source         = "./modules/sonarqube"
  name           = local.name_prefix
  vpc            = module.vpc.vpc_id
  vpc_cidr_block = "10.0.0.0/16"
  keypair        = var.keypair
  subnet_id      = module.vpc.public_subnet_ids[0]
  subnets        = module.vpc.public_subnet_ids
  certificate    = aws_acm_certificate.wildcard.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}

module "prod_env" {
  source            = "./modules/prod-env"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  bastion_sg_id     = module.bastion.bastion_sg
  keypair           = var.keypair
  private_subnet1   = module.vpc.private_subnet_ids[0]
  private_subnet2   = module.vpc.private_subnet_ids[1]
  public_subnet1    = module.vpc.public_subnet_ids[0]
  public_subnet2    = module.vpc.public_subnet_ids[1]
  acm_cert_arn      = aws_acm_certificate.wildcard.arn
  domain_name       = var.domain_name
  nexus_ip          = module.nexus.nexus_ip
  nr_key            = var.nr_key
  nr_acc_id         = var.nr_acc_id
  ansible_sg_id     = module.ansible.ansible_sg
}

module "stage_env" {
  source            = "./modules/stage-env"
  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  bastion_sg_id     = module.bastion.bastion_sg
  keypair           = var.keypair
  private_subnet1   = module.vpc.private_subnet_ids[0]
  private_subnet2   = module.vpc.private_subnet_ids[1]
  public_subnet1    = module.vpc.public_subnet_ids[0]
  public_subnet2    = module.vpc.public_subnet_ids[1]
  acm_cert_arn      = aws_acm_certificate.wildcard.arn
  domain_name       = var.domain_name
  nexus_ip          = module.nexus.nexus_ip
  nr_key            = var.nr_key
  nr_acc_id         = var.nr_acc_id
  ansible_sg_id     = module.ansible.ansible_sg
}

module "nexus" {
  source             = "./modules/nexus"
  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  keypair            = var.keypair
  subnet_id          = module.vpc.private_subnet_ids[0]
  public_subnet_ids  = module.vpc.public_subnet_ids
  ssl_certificate_arn= aws_acm_certificate.wildcard.arn
  hosted_zone_id     = data.aws_route53_zone.zone.id
  domain_name        = var.domain_name
  tags               = {}
}
