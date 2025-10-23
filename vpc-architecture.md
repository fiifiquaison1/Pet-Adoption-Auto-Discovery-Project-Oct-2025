# VPC Architecture - Public Subnets Only

## Overview
This VPC configuration creates a **simplified, cost-effective** setup perfect for Jenkins and Vault servers that need direct internet access.

## What Gets Created
✅ **1 VPC** (10.0.0.0/16)
✅ **2 Public Subnets** (10.0.1.0/24, 10.0.2.0/24) across 2 AZs
✅ **1 Internet Gateway** (for internet access)
✅ **1 Public Route Table** (routes traffic to internet gateway)

## What Does NOT Get Created (Cost Savings)
❌ **No Private Subnets** (not needed for our use case)
❌ **No NAT Gateways** (saves ~$45/month per NAT gateway)
❌ **No Elastic IPs for NAT** (saves ~$3.65/month per IP)
❌ **No Private Route Tables** (simpler management)

## Architecture Benefits

### 🏗️ **Simplified Infrastructure**
- Minimal resource count
- Easier to troubleshoot
- Faster deployment
- Lower complexity

### 💰 **Cost Optimized**
- No NAT Gateway costs (~$45-90/month savings)
- No additional Elastic IP costs
- Reduced data transfer charges

### 🔒 **Still Secure**
- Security groups control access
- Only necessary ports exposed
- SSL/TLS encryption via ACM certificates
- Instance-level security via IAM roles

### 🚀 **Perfect for CI/CD**
- Jenkins servers need internet access for:
  - Downloading dependencies
  - Connecting to GitHub/GitLab
  - Pulling Docker images
  - Installing tools and packages

- Vault servers need internet access for:
  - AWS KMS integration
  - Package updates
  - API communications

## Network Flow
```
Internet → Internet Gateway → Public Subnets → EC2 Instances
                                ↓
                         Jenkins/Vault Services
                                ↓
                          Application Load Balancers
                                ↓
                            Route53 DNS
                                ↓
                       SSL Certificates (ACM)
```

## Security Model
- **Network Level**: VPC isolation + Security Groups
- **Instance Level**: IAM roles + SSH key pairs
- **Application Level**: Jenkins authentication + Vault secrets
- **Transport Level**: SSL/TLS certificates + HTTPS-only

## Availability & Resilience
- **Multi-AZ**: Subnets in eu-west-3a and eu-west-3b
- **Load Balancers**: ELB distributes traffic across instances
- **Health Checks**: Automatic failure detection and routing
- **DNS Failover**: Route53 manages service discovery

This architecture provides **production-ready reliability** while maintaining **simplicity and cost-effectiveness** for your Pet Adoption Auto Discovery project.