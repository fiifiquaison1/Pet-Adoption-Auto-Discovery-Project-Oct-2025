# VPC Module for Pet Adoption Auto Discovery Project
# This module creates a VPC with 2 public and 2 private subnets, internet gateway, NAT gateways and routing

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# Create public subnets
resource "aws_subnet" "pub_sub" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pub-sub-${count.index + 1}"
    Type = "Public"
    AZ   = var.availability_zones[count.index]
  })
}

# Create private subnets
resource "aws_subnet" "priv_sub" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-priv-sub-${count.index + 1}"
    Type = "Private"
    AZ   = var.availability_zones[count.index]
  })
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip" {
  count = length(var.public_subnet_cidrs)
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# Create NAT Gateways
resource "aws_nat_gateway" "nat_gw" {
  count = length(var.public_subnet_cidrs)
  
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.pub_sub[count.index].id
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gw-${count.index + 1}"
    AZ   = var.availability_zones[count.index]
  })
}

# Create route table for public subnets
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pub-rt"
  })
}

# Create route tables for private subnets
resource "aws_route_table" "priv_rt" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id = aws_vpc.vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-priv-rt-${count.index + 1}"
    AZ   = var.availability_zones[count.index]
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "ass_pub_sub" {
  count = length(var.public_subnet_cidrs)
  
  subnet_id      = aws_subnet.pub_sub[count.index].id
  route_table_id = aws_route_table.pub_rt.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "ass_priv_sub" {
  count = length(var.private_subnet_cidrs)
  
  subnet_id      = aws_subnet.priv_sub[count.index].id
  route_table_id = aws_route_table.priv_rt[count.index].id
}