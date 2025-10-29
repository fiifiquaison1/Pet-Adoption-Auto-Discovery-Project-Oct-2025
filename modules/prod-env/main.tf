# Prod Security Group
resource "aws_security_group" "prod_sg" {
  name        = "petadopt-prod-sg"
  description = "Prod security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH access from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id, var.ansible_sg_id]
  }

  ingress {
    description     = "HTTP access from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_elb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petadopt-prod-sg"
  }
}

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

# RedHat AMI
resource "aws_launch_template" "prod_launch_template" {
  image_id      = data.aws_ami.redhat.id
  name_prefix   = "petadopt-prod-web-tmpl"
  instance_type = "t2.medium"
  key_name      = var.keypair
  user_data     = base64encode(templatefile("${path.module}/docker-script.sh", {
    nexus_ip   = var.nexus_ip,
    nr_key     = var.nr_key,
    nr_acc_id  = var.nr_acc_id,
    BASH_SOURCE = var.BASH_SOURCE,
    color      = var.color,
    message    = var.message,
    NC         = var.NC,
    BLUE       = var.BLUE,
    GREEN      = var.GREEN,
    YELLOW     = var.YELLOW,
    RED        = var.RED
  }))

  network_interfaces {
    security_groups = [aws_security_group.prod_sg.id]
  }
  metadata_options {
    http_tokens = "required"
  }
}

resource "aws_autoscaling_group" "prod_asg" {
  name                      = "petadopt-prod-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [var.private_subnet1, var.private_subnet2]
  target_group_arns   = [aws_lb_target_group.prod_target_group.arn]

  tag {
    key                 = "Name"
    value               = "petadopt-prod-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "prod_asg_policy" {
  name                   = "asg-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.prod_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_security_group" "prod_elb_sg" {
  name        = "petadopt-prod-elb-sg"
  description = "Prod ELB security group"
  vpc_id      = var.vpc_id
  ingress {
    description = "HTTPS access from ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "petadopt-prod-elb-sg"
  }
}

resource "aws_lb" "prod_lb" {
  name               = "petadopt-prod-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_elb_sg.id]
  subnets            = [var.public_subnet1, var.public_subnet2]
  tags = {
    Name = "petadopt-prod-lb"
  }
}

resource "aws_lb_target_group" "prod_target_group" {
  name        = "petadopt-prod-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    path                = "/"
  }
  tags = {
    Name = "petadopt-prod-tg"
  }
}

resource "aws_lb_listener" "prod_lb_listener_http" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_target_group.arn
  }
}

resource "aws_lb_listener" "prod_lb_listener_https" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_target_group.arn
  }
}

data "aws_route53_zone" "prod_zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "prod_record" {
  zone_id = data.aws_route53_zone.prod_zone.zone_id
  name    = "prod.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.prod_lb.dns_name
    zone_id                = aws_lb.prod_lb.zone_id
    evaluate_target_health = true
  }
}