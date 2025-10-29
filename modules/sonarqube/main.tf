##############################################
# SECURITY GROUPS
##############################################
resource "aws_security_group" "lb_sg" {
  name        = "petadopt-sonar-lb-sg"
  description = "Allow inbound HTTPS for SonarQube ALB"
  vpc_id      = var.vpc

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petadopt-lb-sg"
  }
}

resource "aws_security_group" "sonarqube_sg" {
  name        = "petadopt-sonar-sg"
  description = "Allow inbound from ALB only"
  vpc_id      = var.vpc

  ingress {
    description     = "SonarQube Web UI"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petadopt-sonar-sg"
  }
}

##############################################
# IAM ROLE + PROFILE
##############################################
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sonarqube_role" {
  name               = "petadopt-sonar-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json

  tags = {
    Name = "petadopt-sonar-role"
  }
}

resource "aws_iam_role_policy" "sonarqube_custom" {
  name = "petadopt-sonar-policy"
  role = aws_iam_role.sonarqube_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "secretsmanager:GetSecretValue"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonarqube_profile" {
  name = "petadopt-sonar-profile"
  role = aws_iam_role.sonarqube_role.name
}

##############################################
# LATEST UBUNTU AMI
##############################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

##############################################
# EC2 INSTANCE (SONARQUBE)
##############################################
resource "aws_instance" "sonarqube" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.sonarqube_profile.name
  user_data              = file("${path.module}/sonar-userdata.sh")
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "petadopt-sonar-server"
  }
}

##############################################
# APPLICATION LOAD BALANCER (ALB)
##############################################
resource "aws_lb" "sonar_alb" {
  name               = "petadopt-sonar-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnets
  security_groups    = [aws_security_group.lb_sg.id]
  enable_deletion_protection = false

  tags = {
    Name = "petadopt-sonar-alb"
  }
}

resource "aws_lb_target_group" "sonar_tg" {
  name     = "petadopt-sonar-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = var.vpc

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "attach_sonar" {
  target_group_arn = aws_lb_target_group.sonar_tg.arn
  target_id        = aws_instance.sonarqube.id
  port             = 9000
}

##############################################
# ACM + ROUTE53
##############################################
resource "aws_acm_certificate" "sonar_cert" {
  domain_name       = "sonar.${var.domain_name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sonar_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "sonar_cert_validation" {
  certificate_arn         = aws_acm_certificate.sonar_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

##############################################
# HTTPS LISTENER
##############################################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.sonar_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.sonar_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonar_tg.arn
  }
}

##############################################
# ROUTE53 RECORD (ALIAS)
##############################################
resource "aws_route53_record" "sonarqube_dns" {
  zone_id = var.hosted_zone_id
  name    = "sonar.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.sonar_alb.dns_name
    zone_id                = aws_lb.sonar_alb.zone_id
    evaluate_target_health = true
  }
}
