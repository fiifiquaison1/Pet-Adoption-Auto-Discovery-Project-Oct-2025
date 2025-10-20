# Database Module - Main Configuration
# RDS MySQL database with security group for Pet Adoption Auto Discovery Project

data "vault_generic_secret" "vault_secret" {
  path = "secret/database"
}

# RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.name_prefix}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for Multi-AZ RDS deployment"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# RDS Security Group
resource "aws_security_group" "db_sg" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS Security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL port"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.security_group_ids
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# RDS MySQL Database Instance
resource "aws_db_instance" "mysql_database" {
  identifier             = "${var.name_prefix}-db"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_name                = "petclinic"

  # High Availability
  multi_az = false

  # Engine Settings
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  parameter_group_name = "default.mysql5.7"

  # Storage
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  # Credentials (Fetch from Vault Manager)
  username = data.vault_generic_secret.vault_secret.data["username"]
  password = data.vault_generic_secret.vault_secret.data["password"]

  # Backup & Maintenance
  skip_final_snapshot = true

  # Security
  publicly_accessible = false
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql-database"
  })
}