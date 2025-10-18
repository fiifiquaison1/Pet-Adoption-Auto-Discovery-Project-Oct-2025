# Fiifi Pet Adoption Auto Discovery Project - Vault-Jenkins Infrastructure
# Main Terraform configuration for eu-west-3 region

locals {
  name = "fiifi-pet-adoption-auto-discovery"
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Create public subnet 1
resource "aws_subnet" "pub_sub" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-pub-sub"
    Type = "Public"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.name}-igw"
  }
}

# Create route table for public subnet
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-pub-rt"
  }
}

# Creating route table association for public_subnet_1
resource "aws_route_table_association" "ass-public_subnet" {
  subnet_id      = aws_subnet.pub_sub.id
  route_table_id = aws_route_table.pub_rt.id
}

# Create keypair resource
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}

resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.keypair.public_key_openssh

  tags = {
    Name = "${local.name}-key"
  }
}

# Data source to get the latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat's owner ID
  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create IAM role for Jenkins server to assume SSM role
resource "aws_iam_role" "ssm-jenkins-role" {
  name = "${local.name}-ssm-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name}-ssm-jenkins-role"
  }
}

# Attach AmazonSSMManaged policy to JENKINS IAM role
resource "aws_iam_role_policy_attachment" "jenkins_ssm_managed_instance_core" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach ADMINISTRATOR ACCESS policy to the role
resource "aws_iam_role_policy_attachment" "jenkins-admin-role-attachment" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# CREATE INSTANCE PROFILE FOR JENKINS SERVER
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.name}-ssm-jenkins-profile"
  role = aws_iam_role.ssm-jenkins-role.name
}

# Create jenkins security group
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow SSH and Jenkins access"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Jenkins web interface"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins-server" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.public_key.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.pub_sub.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true

    tags = {
      Name = "${local.name}-jenkins-root"
    }
  }

  user_data = base64encode(file("./jenkins-userdata.sh"))

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "${local.name}-jenkins-server"
    Type        = "Jenkins-Server"
    OS          = "RedHat"
    Environment = var.environment
    Role        = "CI/CD-Server"
  }
}

# Create Route53 hosted zone for the domain
resource "aws_route53_zone" "fiifi_zone" {
  name = var.domain_name

  tags = {
    Name = "${local.name}-hosted-zone"
  }
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "fiifi_acm_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

# Fetch DNS Validation Records for ACM Certificate
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.fiifi_acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Create DNS Validation Record for ACM Certificate
  zone_id         = aws_route53_zone.fiifi_zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  depends_on      = [aws_acm_certificate.fiifi_acm_cert]
}

# Validate the ACM Certificate after DNS Record Creation
resource "aws_acm_certificate_validation" "fiifi_cert_validation" {
  certificate_arn         = aws_acm_certificate.fiifi_acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
  depends_on              = [aws_acm_certificate.fiifi_acm_cert]
}

# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins-elb-sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allow HTTPS for Jenkins ELB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}

# Create elastic Load Balancer for Jenkins
resource "aws_elb" "elb_jenkins" {
  name            = "fiifi-pet-adoption-jenkins-elb"
  security_groups = [aws_security_group.jenkins-elb-sg.id]
  subnets         = [aws_subnet.pub_sub.id]

  listener {
    instance_port     = 8080
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate_validation.fiifi_cert_validation.certificate_arn
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }

  instances                   = [aws_instance.jenkins-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-jenkins-elb"
  }
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create KMS key to manage vault unseal keys
resource "aws_kms_key" "vault" {
  description             = "KMS key for Fiifi Pet Adoption Auto Discovery Vault"
  enable_key_rotation     = true
  deletion_window_in_days = 20

  tags = {
    Name = "${local.name}-vault-kms-key"
  }
}

# Create a vault server
resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.pub_sub.id
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]
  key_name                    = aws_key_pair.public_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vault_ssm_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true

    tags = {
      Name = "${local.name}-vault-root"
    }
  }

  # User data script to install Vault and required tools
  user_data = templatefile("./vault-userdata.sh", {
    region        = var.aws_region,
    VAULT_VERSION = "1.18.3",
    key           = aws_kms_key.vault.id
  })

  metadata_options {
    http_tokens = "required"
  }

  # Tag the instance for easy identification
  tags = {
    Name        = "${local.name}-vault-server"
    Type        = "Vault-Server"
    OS          = "Ubuntu"
    Environment = var.environment
    Role        = "Secrets-Management"
  }
}

# Security Group for Vault server
resource "aws_security_group" "vault_sg" {
  name        = "${local.name}-vault-sg"
  description = "Allow Vault traffic"
  vpc_id      = aws_vpc.vpc.id

  # Vault API and UI
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Vault API and UI"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Outbound: Allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${local.name}-vault-sg"
  }
}

# Creating and attaching an IAM role with SSM permissions to the vault instance
resource "aws_iam_role" "vault_ssm_role" {
  name = "${local.name}-ssm-vault-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name}-ssm-vault-role"
  }
}

# Create IAM role policy to give permission to the KMS role
resource "aws_iam_role_policy" "kms_policy" {
  name = "${local.name}-kms-policy"
  role = aws_iam_role.vault_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDatakey*",
          "kms:DescribeKey"
        ],
        Effect   = "Allow"
        Resource = aws_kms_key.vault.arn
      }
    ]
  })
}

# Attach the AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "vault_ssm_attachment" {
  role       = aws_iam_role.vault_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile for vault
resource "aws_iam_instance_profile" "vault_ssm_profile" {
  name = "${local.name}-ssm-vault-instance-profile"
  role = aws_iam_role.vault_ssm_role.id
}

# Security Group for Vault ELB
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Allow HTTPS traffic for Vault ELB"
  vpc_id      = aws_vpc.vpc.id

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # Outbound: Allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${local.name}-vault-elb-sg"
  }
}

# Create a new load balancer for vault
resource "aws_elb" "vault_elb" {
  name            = "fiifi-pet-adoption-vault-elb"
  subnets         = [aws_subnet.pub_sub.id]
  security_groups = [aws_security_group.vault_elb_sg.id]

  listener {
    instance_port     = 8200
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  listener {
    instance_port      = 8200
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate_validation.fiifi_cert_validation.certificate_arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
    interval            = 30
  }

  instances                   = [aws_instance.vault.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-vault-elb"
  }
}

# Create Route 53 record for vault server
resource "aws_route53_record" "vault_record" {
  zone_id = aws_route53_zone.fiifi_zone.zone_id
  name    = "vault.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
}

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins_record" {
  zone_id = aws_route53_zone.fiifi_zone.zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}