# Fiifi Pet Adoption Auto Discovery Project - Vault-Jenkins Infrastructure
# Main Terraform configuration for eu-west-3 region

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Fiifi-Pet-Adoption-Auto-Discovery"
      Environment = var.environment
      Owner       = "fiifiquaison1"
      ManagedBy   = "Terraform"
      CreatedDate = timestamp()
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat
  
  filter {
    name   = "name"
    values = ["RHEL-9*-x86_64-*"]
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

# Data source for existing Route53 hosted zone (if it exists)
data "aws_route53_zone" "domain" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.domain_name
}

# Create Route53 hosted zone (if requested)
resource "aws_route53_zone" "domain" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.domain_name
  
  tags = {
    Name = "${var.project_name}-zone"
  }
}

# VPC
resource "aws_vpc" "pet_adoption_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "pet_adoption_igw" {
  vpc_id = aws_vpc.pet_adoption_vpc.id
  
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.pet_adoption_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.pet_adoption_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.pet_adoption_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pet_adoption_igw.id
  }
  
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_rta" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
  
  depends_on = [aws_internet_gateway.pet_adoption_igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  
  tags = {
    Name = "${var.project_name}-nat-gw"
  }
  
  depends_on = [aws_internet_gateway.pet_adoption_igw]
}

# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.pet_adoption_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  
  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name_prefix = "${var.project_name}-jenkins-"
  vpc_id      = aws_vpc.pet_adoption_vpc.id
  
  description = "Security group for Jenkins server"
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }
  
  # Jenkins web interface
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_web_cidrs
    description = "Jenkins web interface"
  }
  
  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

# Security Group for Vault
resource "aws_security_group" "vault_sg" {
  name_prefix = "${var.project_name}-vault-"
  vpc_id      = aws_vpc.pet_adoption_vpc.id
  
  description = "Security group for Vault server"
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }
  
  # Vault API
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Vault API and UI from VPC"
  }
  
  # Vault cluster communication
  ingress {
    from_port = 8201
    to_port   = 8201
    protocol  = "tcp"
    self      = true
    description = "Vault cluster communication"
  }
  
  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-vault-sg"
  }
}

# IAM Role for Jenkins
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-jenkins-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.project_name}-jenkins-role"
  }
}

# IAM Policy for Jenkins
resource "aws_iam_role_policy" "jenkins_policy" {
  name = "${var.project_name}-jenkins-policy"
  role = aws_iam_role.jenkins_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "ec2:Describe*",
          "ec2:CreateTags",
          "iam:PassRole",
          "iam:ListRoles",
          "iam:ListInstanceProfiles",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for Jenkins
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

# IAM Role for Vault
resource "aws_iam_role" "vault_role" {
  name = "${var.project_name}-vault-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.project_name}-vault-role"
  }
}

# IAM Policy for Vault
resource "aws_iam_role_policy" "vault_policy" {
  name = "${var.project_name}-vault-policy"
  role = aws_iam_role.vault_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "iam:GetRole",
          "iam:GetUser",
          "sts:GetCallerIdentity",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for Vault
resource "aws_iam_instance_profile" "vault_profile" {
  name = "${var.project_name}-vault-profile"
  role = aws_iam_role.vault_role.name
}

# Key Pair
resource "aws_key_pair" "pet_adoption_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key
  
  tags = {
    Name = "${var.project_name}-key"
  }
}

# Jenkins EC2 Instance (Red Hat)
resource "aws_instance" "jenkins" {
  ami                     = data.aws_ami.redhat.id
  instance_type           = var.jenkins_instance_type
  key_name                = aws_key_pair.pet_adoption_key.key_name
  vpc_security_group_ids  = [aws_security_group.jenkins_sg.id]
  subnet_id               = aws_subnet.public_subnets[0].id
  iam_instance_profile    = aws_iam_instance_profile.jenkins_profile.name
  
  user_data = base64encode(file("${path.module}/jenkins-userdata.sh"))
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.jenkins_root_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-jenkins-root"
    }
  }
  
  tags = {
    Name = "${var.project_name}-jenkins"
    Type = "Jenkins-Server"
    OS   = "RedHat"
  }
}

# Vault EC2 Instance (Ubuntu)
resource "aws_instance" "vault" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.vault_instance_type
  key_name                = aws_key_pair.pet_adoption_key.key_name
  vpc_security_group_ids  = [aws_security_group.vault_sg.id]
  subnet_id               = aws_subnet.private_subnets[0].id
  iam_instance_profile    = aws_iam_instance_profile.vault_profile.name
  
  user_data = base64encode(file("${path.module}/vault-userdata.sh"))
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.vault_root_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-vault-root"
    }
  }
  
  tags = {
    Name = "${var.project_name}-vault"
    Type = "Vault-Server"
    OS   = "Ubuntu"
  }
}

# Application Load Balancer for Jenkins
resource "aws_lb" "jenkins_alb" {
  name               = "fiifi-pet-adoption-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_sg.id]
  subnets            = aws_subnet.public_subnets[*].id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${var.project_name}-jenkins-alb"
  }
}

# Target Group for Jenkins
resource "aws_lb_target_group" "jenkins_tg" {
  name     = "fiifi-pet-adoption-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.pet_adoption_vpc.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/login"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  tags = {
    Name = "${var.project_name}-jenkins-tg"
  }
}

# Target Group Attachment for Jenkins
resource "aws_lb_target_group_attachment" "jenkins_attachment" {
  target_group_arn = aws_lb_target_group.jenkins_tg.arn
  target_id        = aws_instance.jenkins.id
  port             = 8080
}

# ALB Listener for Jenkins
resource "aws_lb_listener" "jenkins_listener" {
  load_balancer_arn = aws_lb.jenkins_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_tg.arn
  }
}

# Route53 Health Check for Jenkins
resource "aws_route53_health_check" "jenkins_health" {
  count                           = var.create_route53_health_checks ? 1 : 0
  fqdn                            = aws_lb.jenkins_alb.dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/login"
  failure_threshold               = "3"
  request_interval                = "30"
  insufficient_data_health_status = "Unhealthy"
  
  tags = {
    Name = "${var.project_name}-jenkins-health-check"
  }
}

# Application Load Balancer for Vault (Internal)
resource "aws_lb" "vault_alb" {
  name               = "fiifi-pet-adoption-vault-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.vault_sg.id]
  subnets            = aws_subnet.private_subnets[*].id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${var.project_name}-vault-alb"
  }
}

# Target Group for Vault
resource "aws_lb_target_group" "vault_tg" {
  name     = "fiifi-pet-adoption-vault-tg"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = aws_vpc.pet_adoption_vpc.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/v1/sys/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  tags = {
    Name = "${var.project_name}-vault-tg"
  }
}

# Target Group Attachment for Vault
resource "aws_lb_target_group_attachment" "vault_attachment" {
  target_group_arn = aws_lb_target_group.vault_tg.arn
  target_id        = aws_instance.vault.id
  port             = 8200
}

# ALB Listener for Vault
resource "aws_lb_listener" "vault_listener" {
  load_balancer_arn = aws_lb.vault_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault_tg.arn
  }
}

# Route53 DNS Records
locals {
  zone_id = var.create_route53_zone ? aws_route53_zone.domain[0].zone_id : data.aws_route53_zone.domain[0].zone_id
}

# Jenkins DNS Record
resource "aws_route53_record" "jenkins" {
  zone_id = local.zone_id
  name    = "${var.jenkins_subdomain}.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_lb.jenkins_alb.dns_name
    zone_id                = aws_lb.jenkins_alb.zone_id
    evaluate_target_health = true
  }
}

# Vault DNS Record (Internal ALB)
resource "aws_route53_record" "vault" {
  zone_id = local.zone_id
  name    = "${var.vault_subdomain}.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_lb.vault_alb.dns_name
    zone_id                = aws_lb.vault_alb.zone_id
    evaluate_target_health = true
  }
}

# Root domain record (pointing to Jenkins)
resource "aws_route53_record" "root" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_lb.jenkins_alb.dns_name
    zone_id                = aws_lb.jenkins_alb.zone_id
    evaluate_target_health = true
  }
}

# WWW subdomain record
resource "aws_route53_record" "www" {
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "jenkins_logs" {
  name              = "/aws/ec2/${var.project_name}/jenkins"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${var.project_name}-jenkins-logs"
  }
}

resource "aws_cloudwatch_log_group" "vault_logs" {
  name              = "/aws/ec2/${var.project_name}/vault"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${var.project_name}-vault-logs"
  }
}