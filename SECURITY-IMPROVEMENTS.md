# Secure Key Management Guide

## Security Issue Resolved
Private SSH keys were being generated in the repository directory and could be accidentally committed to version control.

## New Secure Approach

### 1. Private Key Storage
- Private keys are generated locally but **NEVER committed** to git
- Added comprehensive `.gitignore` rules for all sensitive files
- Keys are automatically created in a secure location during deployment

### 2. Key Management Best Practices

#### For Development/Testing:
```bash
# Keys are generated automatically during deployment
./modules/stage-env/docker-script.sh --deploy

# Keys are stored locally and automatically cleaned up
./modules/stage-env/docker-script.sh --destroy
```

#### For Production:
```bash
# Option 1: Use deployment script (generates temporary keys)
./modules/prod-env/docker-script.sh

# Option 2: Use existing AWS key pair (recommended)
# Set TF_VAR_use_existing_keypair=true
# Set TF_VAR_existing_keypair_name=your-existing-key
```

### 3. Security Improvements Implemented

#### Updated .gitignore:
- `*.pem` - All PEM files
- `*.key` - All key files
- `*.p12`, `*.pfx` - Certificate files
- AWS credentials and SSH keys
- Environment files with secrets

#### Terraform Configuration:
- Added lifecycle rules to prevent key commits
- Keys generated with restricted permissions (400)
- Automatic cleanup during destroy operations

#### Deployment Scripts:
- Keys stored in temporary locations
- Automatic cleanup after deployments
- Warning messages about key security

### 4. Recommended Production Setup

#### Option A: Pre-existing Key Pair (Recommended)
1. Create key pair outside of Terraform:
```bash
# Create key pair manually
aws ec2 create-key-pair --key-name "prod-pet-adoption-key" --region eu-west-3 --output text --query 'KeyMaterial' > ~/secure-keys/prod-pet-adoption-key.pem
chmod 400 ~/secure-keys/prod-pet-adoption-key.pem
```

2. Update terraform variables:
```bash
export TF_VAR_use_existing_keypair=true
export TF_VAR_existing_keypair_name="prod-pet-adoption-key"
```

#### Option B: External Key Management (Enterprise)
- Use AWS Systems Manager Parameter Store for keys
- Use AWS Secrets Manager for sensitive data
- Use external key management systems (HashiCorp Vault, etc.)

### 5. Emergency Key Recovery

If keys are compromised:

```bash
# 1. Immediately rotate the key pair
aws ec2 delete-key-pair --key-name "old-compromised-key" --region eu-west-3

# 2. Create new key pair
aws ec2 create-key-pair --key-name "new-secure-key" --region eu-west-3

# 3. Update instances (requires redeployment)
./modules/prod-env/docker-script.sh --destroy
# Update key configuration
./modules/prod-env/docker-script.sh --deploy
```

### 6. Access Control

#### SSH Access:
```bash
# Connect to instances (when keys are properly managed)
ssh -i ~/secure-keys/prod-pet-adoption-key.pem ec2-user@<instance-ip>
```

#### AWS Systems Manager (Recommended):
```bash
# Connect without SSH keys (more secure)
aws ssm start-session --target <instance-id> --region eu-west-3
```

### 7. Monitoring and Auditing

- Monitor AWS CloudTrail for key usage
- Set up alerts for unauthorized access attempts
- Regular key rotation (recommended: every 90 days)
- Document all key management procedures

## Security Checklist

- ✅ Private keys never committed to repository
- ✅ Comprehensive .gitignore for sensitive files  
- ✅ Keys generated with restricted permissions
- ✅ Automatic cleanup during destroy operations
- ✅ Lifecycle rules prevent accidental commits
- ✅ Documentation for secure key management
- ✅ Support for pre-existing key pairs
- ✅ Systems Manager integration for keyless access

## Notes

1. **Never commit private keys**: Always use .gitignore and lifecycle rules
2. **Use temporary keys for testing**: Staging environments should use temporary keys
3. **Use managed keys for production**: Pre-existing or externally managed keys preferred
4. **Regular rotation**: Rotate keys regularly for security
5. **Monitor access**: Use CloudTrail and AWS Config for monitoring
6. **Document procedures**: Maintain clear security procedures for the team