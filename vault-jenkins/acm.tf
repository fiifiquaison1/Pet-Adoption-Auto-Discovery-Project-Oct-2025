# ===============================
# ACM Certificate Management - Fiifi Pet Adoption Auto Discovery Project
# SSL/TLS certificates for Jenkins and Vault services with automated Route53 validation
# ===============================

# Fetch Route 53 hosted zone
data "aws_route53_zone" "primary" {
  name         = "fiifiquaison.space."
  private_zone = false
}

# Jenkins ACM Certificate
resource "aws_acm_certificate" "jenkins_cert" {
  domain_name       = "jenkins.fiifiquaison.space"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name    = "${local.name}-jenkins-cert"
    Service = "Jenkins"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Vault ACM Certificate
resource "aws_acm_certificate" "vault_cert" {
  domain_name       = "vault.fiifiquaison.space"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name    = "${local.name}-vault-cert"
    Service = "Vault"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS validation record for Jenkins
resource "aws_route53_record" "jenkins_validation" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = tolist(aws_acm_certificate.jenkins_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.jenkins_cert.domain_validation_options)[0].resource_record_type
  ttl     = 300
  records = [tolist(aws_acm_certificate.jenkins_cert.domain_validation_options)[0].resource_record_value]
  
  allow_overwrite = true
}

# Create DNS validation record for Vault
resource "aws_route53_record" "vault_validation" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = tolist(aws_acm_certificate.vault_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.vault_cert.domain_validation_options)[0].resource_record_type
  ttl     = 300
  records = [tolist(aws_acm_certificate.vault_cert.domain_validation_options)[0].resource_record_value]
  
  allow_overwrite = true
}

# Validate Jenkins ACM Certificate
resource "aws_acm_certificate_validation" "jenkins_cert_validation" {
  certificate_arn         = aws_acm_certificate.jenkins_cert.arn
  validation_record_fqdns = [aws_route53_record.jenkins_validation.fqdn]

  timeouts {
    create = "30m"
  }

  depends_on = [aws_route53_record.jenkins_validation]
}

# Validate Vault ACM Certificate
resource "aws_acm_certificate_validation" "vault_cert_validation" {
  certificate_arn         = aws_acm_certificate.vault_cert.arn
  validation_record_fqdns = [aws_route53_record.vault_validation.fqdn]

  timeouts {
    create = "30m"
  }

  depends_on = [aws_route53_record.vault_validation]
}