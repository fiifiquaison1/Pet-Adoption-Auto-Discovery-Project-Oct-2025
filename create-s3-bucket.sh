#!/bin/bash

# Pet Adoption Auto Discovery Project - S3 Bucket Creation and Deployment Script
# This script creates S3 bucket, enables versioning, and deploys infrastructure

set -euo pipefail

# Configuration variables
BUCKET_NAME="auto-discovery-fiifi-1986"
AWS_REGION="eu-west-3"
AWS_PROFILE="pet-adoption"
PROJECT_TAG="Fiifi-Pet-Adoption-Auto-Discovery"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Check if AWS profile exists
check_aws_profile() {
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        print_status "$YELLOW" "⚠️  AWS profile '${AWS_PROFILE}' not found, using default profile"
        AWS_PROFILE="default"
    fi
}

# Check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_status "$RED" "❌ AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

echo "🪣 Pet Adoption Auto Discovery - S3 Bucket Creation and Deployment"
echo "=================================================================="
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo ""

# Check prerequisites
check_aws_cli
check_aws_profile

print_status "$BLUE" "📦 Creating S3 bucket for Terraform state..."

# Create S3 bucket with proper region configuration
if [[ "$AWS_REGION" == "us-east-1" ]]; then
    # us-east-1 doesn't need LocationConstraint
    aws_create_cmd="aws s3api create-bucket --bucket \"$BUCKET_NAME\" --region \"$AWS_REGION\" --profile \"$AWS_PROFILE\""
else
    # Other regions need LocationConstraint
    aws_create_cmd="aws s3api create-bucket --bucket \"$BUCKET_NAME\" --region \"$AWS_REGION\" --profile \"$AWS_PROFILE\" --create-bucket-configuration LocationConstraint=\"$AWS_REGION\""
fi

if eval $aws_create_cmd; then
    print_status "$GREEN" "✅ S3 bucket created: $BUCKET_NAME"
else
    print_status "$RED" "❌ Failed to create S3 bucket"
    exit 1
fi

# Enable versioning
print_status "$BLUE" "🔄 Enabling bucket versioning..."
if aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --versioning-configuration Status=Enabled; then
    print_status "$GREEN" "✅ Bucket versioning enabled"
else
    print_status "$RED" "❌ Failed to enable versioning"
    exit 1
fi

# Add security configurations
print_status "$BLUE" "🔒 Configuring bucket security..."

# Block public access
if aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --profile "$AWS_PROFILE" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true; then
    print_status "$GREEN" "✅ Public access blocked"
else
    print_status "$YELLOW" "⚠️  Failed to block public access"
fi

# Add tags
if aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --profile "$AWS_PROFILE" \
    --tagging "TagSet=[
        {Key=Project,Value=$PROJECT_TAG},
        {Key=Environment,Value=shared},
        {Key=ManagedBy,Value=Script},
        {Key=Purpose,Value=TerraformState}
    ]"; then
    print_status "$GREEN" "✅ Bucket tagged"
else
    print_status "$YELLOW" "⚠️  Failed to add tags"
fi

# Save bucket configuration
print_status "$BLUE" "💾 Saving bucket configuration..."
cat > bucket-info.txt << EOF
# Pet Adoption Auto Discovery - S3 Bucket Configuration
# Generated on: $(date)

BUCKET_NAME=$BUCKET_NAME
AWS_REGION=$AWS_REGION
AWS_PROFILE=$AWS_PROFILE
PROJECT_TAG=$PROJECT_TAG

# Use this information to configure Terraform backend
# backend "s3" {
#   bucket = "$BUCKET_NAME"
#   key    = "terraform.tfstate"
#   region = "$AWS_REGION"
# }
EOF

print_status "$GREEN" "✅ S3 bucket setup completed!"
print_status "$BLUE" "📝 Configuration saved to: bucket-info.txt"

# Deploy Vault and Jenkins infrastructure
print_status "$BLUE" "🚀 Creating Vault and Jenkins Server..."

if [[ ! -d "vault-jenkins" ]]; then
    print_status "$RED" "❌ vault-jenkins directory not found"
    exit 1
fi

cd vault-jenkins

# Initialize Terraform
print_status "$BLUE" "🔧 Initializing Terraform..."
if terraform init; then
    print_status "$GREEN" "✅ Terraform initialized"
else
    print_status "$RED" "❌ Terraform initialization failed"
    exit 1
fi

# Validate configuration
print_status "$BLUE" "🔍 Validating Terraform configuration..."
if terraform validate; then
    print_status "$GREEN" "✅ Terraform configuration valid"
else
    print_status "$RED" "❌ Terraform validation failed"
    exit 1
fi

# Apply deployment
print_status "$BLUE" "🚀 Applying Terraform deployment..."
if terraform apply -auto-approve; then
    print_status "$GREEN" "🎉 Deployment completed successfully!"
    
    # Show outputs
    echo ""
    print_status "$BLUE" "📊 Deployment Outputs:"
    terraform output
else
    print_status "$RED" "❌ Terraform deployment failed"
    exit 1
fi

print_status "$GREEN" "✅ Complete! Infrastructure deployed successfully!"
print_status "$BLUE" "📝 Next steps:"
echo "  - Check the deployment outputs above"
echo "  - Verify resources in AWS Console"
echo "  - Use destroy-s3-bucket.sh to clean up when done"