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

# Local values for Ansible configuration
locals {
  ansible_userdata = base64encode(templatefile("${path.module}/userdata/ansible-setup.sh", {
    nexus_server_ip       = var.nexus_server_ip
    new_relic_license_key = var.new_relic_license_key
    new_relic_account_id  = var.new_relic_account_id
    s3_bucket_name        = var.s3_bucket_name
  }))
}

# Creating ansible security group with enhanced security
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name_prefix}-ansible-sg"
  description = "Allow SSH access for Ansible server - restricted to bastion only"
  vpc_id      = var.vpc_id

  # SSH access only from bastion host
  ingress {
    description     = "SSH port from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  # HTTPS outbound for package downloads and API calls
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP outbound for package downloads
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS outbound
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH outbound to managed instances (within VPC only)
  egress {
    description = "SSH to managed instances"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ansible-sg"
  })
}

# Data source to get VPC CIDR for security group rules
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Create Ansible Server with enhanced security
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.redhat.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               = var.key_pair_name
  subnet_id              = var.private_subnet_id
  user_data_base64       = local.ansible_userdata

  # Security: No public IP (private subnet only)
  associate_public_ip_address = false

  # Security: Disable source/destination checks (not needed for Ansible)
  source_dest_check = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true

    # Security: Delete on termination
    delete_on_termination = true
  }

  # Security: Enhanced metadata options
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
    instance_metadata_tags      = "enabled"
  }

  # Security: Monitoring enabled
  monitoring = true

  # Security: Disable API termination in production
  disable_api_termination = false

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ansible-server"
    Environment = "automation"
    Purpose     = "ansible-automation"
    Security    = "private-subnet-only"
  })
  
  provisioner "remote-exec" {
    inline = [
      "echo Hello from Ansible EC2!",
      "uname -a"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("C:/Users/fiifi/my-personal-proj/Pet-Adoption-Auto-Discovery-Project-Oct-2025/files/fiifi-pet-adoption-auto-discovery-key1.pem")
      host        = self.private_ip
      timeout     = "5m"
      agent       = false
    }
  }
  depends_on = [aws_instance.ansible_server]
}

# Create IAM role for ansible
resource "aws_iam_role" "ansible_role" {
  name = "${var.name_prefix}-ansible-discovery-role"

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ansible-role"
  })
}

# Create custom IAM policy with least privilege for Ansible operations
resource "aws_iam_policy" "ansible_policy" {
  name        = "${var.name_prefix}-ansible-policy"
  description = "Least privilege policy for Ansible automation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 permissions for managing instances
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeTags",
          # Auto Scaling permissions for managing ASGs
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          # Systems Manager for secure access
          "ssm:DescribeInstanceInformation",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # S3 permissions limited to specific bucket
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ansible-policy"
  })
}

# Attach the custom policy to the role
resource "aws_iam_role_policy_attachment" "ansible_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = aws_iam_policy.ansible_policy.arn
}

# Attach SSM managed instance core for secure access
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create IAM instance profile for ansible
resource "aws_iam_instance_profile" "ansible_profile" {
  name = "${var.name_prefix}-ansible-discovery-profile"
  role = aws_iam_role.ansible_role.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ansible-profile"
  })
}

# Upload ansible scripts to S3 (only deploy.yml and scripts)
resource "null_resource" "ansible_setup" {
  # Only upload when instance is created
  depends_on = [aws_instance.ansible_server]

  provisioner "local-exec" {
    command = <<EOT
      REM Create temporary directory for scripts
      mkdir ansible-upload

      REM Copy only necessary files
      copy "${path.module}\deployment.yml" ansible-upload\
      copy "${path.module}\stage-bashscript.sh" ansible-upload\
      copy "${path.module}\prod-bashscript.sh" ansible-upload\

      REM Upload to S3 with versioning
      aws s3 sync ansible-upload/ s3://${var.s3_bucket_name}/ansible-scripts/ --delete

      REM Clean up temporary directory
      rmdir /S /Q ansible-upload
    EOT
    interpreter = ["cmd", "/C"]
  }

  # Trigger re-upload when scripts change
  triggers = {
    deployment_yml_hash = filemd5("${path.module}/deployment.yml")
    stage_script_hash   = filemd5("${path.module}/stage-bashscript.sh")
    prod_script_hash    = filemd5("${path.module}/prod-bashscript.sh")
  }
}
