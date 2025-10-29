# Nexus Module - Main Configuration
# Nexus Repository Manager with Load Balancer and Route53 for Pet Adoption Auto Discovery Project

# Data source to get the latest CentOS AMI
data "aws_ami" "centos" {
  most_recent = true
  owners      = ["125523088429"] # Verified CentOS image owner

  filter {
    name   = "name"
    values = ["CentOS Stream 9*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "lb-sg" {
  name        = "${var.name_prefix}-lb-sg"
  description = "Allow inbound traffic for load balancer and all outbound traffic"
  vpc_id      = var.vpc_id

  # Ingress rule: Allow HTTPS (port 443) from anywhere
  ingress {
    description = "HTTPS (port 443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lb-sg"
  })
}

# Security Group for Nexus Server
resource "aws_security_group" "nexus-sg" {
  name        = "${var.name_prefix}-nexus-sg"
  description = "Allow inbound traffic from load balancer and all outbound traffic"
  vpc_id      = var.vpc_id

  # Ingress rule: Allow Nexus port (8081) from load balancer security group
  ingress {
    description     = "Nexus (port 8081)"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.lb-sg.id]
  }

  # Ingress rule: Allow Docker registry port (8085) from anywhere
  ingress {
    description = "Docker Registry (port 8085)"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule: Allow SSH (port 22) from anywhere (testing only)
  ingress {
    description = "SSH access for provisioning (testing only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nexus-sg"
  })
}

# IAM Role for Nexus Instance
resource "aws_iam_role" "nexus-role" {
  name = "${var.name_prefix}-nexus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nexus-role"
  })
}

# IAM Instance Profile for Nexus
resource "aws_iam_instance_profile" "nexus-profile" {
  name = "${var.name_prefix}-nexus-profile"
  role = aws_iam_role.nexus-role.name
}

# SSM Permission Attachment
resource "aws_iam_role_policy_attachment" "ssm-access" {
  role       = aws_iam_role.nexus-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Nexus Server EC2 Instance
resource "aws_instance" "nexus-server" {
  ami                         = data.aws_ami.centos.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.nexus-sg.id]
  key_name                    = var.keypair
  subnet_id                   = var.subnet_id
  user_data                   = templatefile("${path.module}/nexus-userdata.sh", {
    NEXUS_VERSION = var.nexus_version
    color         = var.color
    message       = var.message
    NC            = var.NC
  })
  iam_instance_profile        = aws_iam_instance_profile.nexus-profile.name
  associate_public_ip_address = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nexus-server"
  })
}

# Load Balancer for Nexus
resource "aws_elb" "nexus-elb" {
  name            = "petadopt-nexus-elb"
  security_groups = [aws_security_group.lb-sg.id]
  subnets         = var.public_subnet_ids

  listener {
    instance_port      = 8081
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = var.ssl_certificate_arn
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8081"
  }

  instances                   = [aws_instance.nexus-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = merge(var.tags, {
  Name = "petadopt-nexus-elb"
  })
}

# Route53 DNS Record for Nexus
resource "aws_route53_record" "nexus" {
  zone_id = var.hosted_zone_id
  name    = "nexus.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.nexus-elb.dns_name
    zone_id                = aws_elb.nexus-elb.zone_id
    evaluate_target_health = true
  }
}

# Update Jenkins Docker Configuration for Nexus Registry
resource "null_resource" "update-jenkins-docker" {
  depends_on = [aws_instance.nexus-server]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.nexus-server.public_ip
      user        = "ubuntu"
      private_key = file("C:/Users/fiifi/my-personal-proj/Pet-Adoption-Auto-Discovery-Project-Oct-2025/files/fiifi-pet-adoption-auto-discovery-key1.pem")
      timeout     = "5m"
      agent       = false
    }

    inline = [
      "echo 'Updating Jenkins Docker...'",
      "sudo docker pull jenkins/jenkins:lts",
      "sudo systemctl restart jenkins"
    ]
  }
}