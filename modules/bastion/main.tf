# Bastion Module - Main Configuration
# Bastion Host with Auto Scaling Group for Pet Adoption Auto Discovery Project

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
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion-sg" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "Allow only outbound traffic for bastion host"
  vpc_id      = var.vpc_id

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
  })
}

# IAM Role for SSM Access
resource "aws_iam_role" "bastion-ssm-role" {
  name = "${var.name_prefix}-bastion-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-ssm-role"
  })
}

# Attach SSM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "bastion-ssm-policy" {
  role       = aws_iam_role.bastion-ssm-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for Bastion Host
resource "aws_iam_instance_profile" "bastion-ssm-profile" {
  name = "${var.name_prefix}-bastion-ssm-profile"
  role = aws_iam_role.bastion-ssm-role.name
}

# Launch Template for Bastion Host
resource "aws_launch_template" "bastion-lt" {
  name_prefix   = "${var.name_prefix}-bastion-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.keypair

  iam_instance_profile {
    name = aws_iam_instance_profile.bastion-ssm-profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.bastion-sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/bastion-userdata.sh", {
  private_key    = file("C:/Users/fiifi/my-personal-proj/Pet-Adoption-Auto-Discovery-Project-Oct-2025/files/fiifi-pet-adoption-auto-discovery-key1.pem")
    nr_license_key = var.nr_license_key
    nr_account_id  = var.nr_account_id
    region         = var.region
  }))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-lt"
  })
}

# Auto Scaling Group for Bastion Host
resource "aws_autoscaling_group" "bastion-asg" {
  name                      = "${var.name_prefix}-bastion-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  vpc_zone_identifier       = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.bastion-lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-bastion-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Auto Scaling Policy for Bastion Host
resource "aws_autoscaling_policy" "bastion-asg-policy" {
  name                   = "${var.name_prefix}-bastion-asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.bastion-asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}