# Pet Adoption Auto Discovery Project

A comprehensive infrastructure-as-code project for deploying a secure, scalable pet adoption platform using AWS, Terraform, Jenkins, and HashiCorp Vault.

## 🏗️ Architecture

- **Jenkins**: CI/CD server for automated deployments
- **Vault**: Secrets management and security
- **AWS Infrastructure**: VPC, EC2, Load Balancers, Route53
- **Terraform**: Infrastructure as Code
- **Multi-Environment**: Production and Staging deployments

## 🚀 Quick Start

### Deploy Infrastructure

```bash
# Production deployment
./modules/prod-env/docker-script.sh

# Staging deployment  
./modules/stage-env/docker-script.sh --quick
```

### Destroy Infrastructure

```bash
# Production destroy
./modules/prod-env/docker-script.sh --destroy

# Staging destroy
./modules/stage-env/docker-script.sh --destroy
```

## 📁 Project Structure

```
├── modules/
│   ├── prod-env/           # Production deployment scripts
│   ├── stage-env/          # Staging deployment scripts
│   └── vpc/                # VPC Terraform module
├── vault-jenkins/          # Main Terraform configuration
├── create-s3-bucket.sh     # S3 bucket creation for remote state
├── destroy-s3-bucket.sh    # Emergency cleanup script
└── manage-state.sh         # Terraform state management
```

## 🔒 Security Features

- ✅ Private keys never committed (protected by .gitignore)
- ✅ Automatic cleanup of sensitive files during destroy operations
- ✅ Comprehensive state management and recovery
- ✅ Secure deployment practices with restricted permissions
- ✅ Emergency key rotation procedures built-in
- ✅ Support for AWS Systems Manager (keyless access)

### Key Security Practices

**SSH Key Management:**
- Keys generated locally with 400 permissions
- Automatic cleanup after deployments
- Never committed to repository (.gitignore protection)
- Support for pre-existing AWS key pairs

**Production Security:**
```bash
# Use existing key pair (recommended for production)
export TF_VAR_use_existing_keypair=true
export TF_VAR_existing_keypair_name="your-existing-key"

# Or use keyless access via AWS Systems Manager
aws ssm start-session --target <instance-id> --region eu-west-3
```

**Emergency Key Recovery:**
```bash
# If keys are compromised
./modules/prod-env/docker-script.sh --destroy
aws ec2 delete-key-pair --key-name "compromised-key" --region eu-west-3
# Deploy with new keys
./modules/prod-env/docker-script.sh
```

## �️ Advanced Features

### Robust Infrastructure Management
- **State Recovery**: Automatic recovery from corrupted Terraform state
- **Fallback Cleanup**: Manual AWS resource cleanup if Terraform fails
- **Enhanced Timeouts**: Extended SSL certificate validation (20min)
- **Backup System**: Automatic state backups before operations
- **Resource Tagging**: Comprehensive tagging for cleanup operations

### Utility Scripts
- `create-s3-bucket.sh` - Create S3 bucket and DynamoDB table for remote state
- `destroy-s3-bucket.sh` - Emergency cleanup of all AWS resources
- `manage-state.sh` - Terraform state management (backup, validate, clean, recover)
- Production & Staging deployment scripts with comprehensive error handling

## 🛠️ Requirements

- AWS CLI configured
- Terraform >= 1.13
- Bash shell
- Appropriate AWS permissions

## ⚡ Features

- **Robust Destroy**: Never leaves orphaned AWS resources
- **State Recovery**: Automatic recovery from corrupted state
- **Multi-Environment**: Separate prod and staging configurations  
- **Security First**: Enterprise-grade security practices
- **Comprehensive Cleanup**: Fallback manual cleanup if needed