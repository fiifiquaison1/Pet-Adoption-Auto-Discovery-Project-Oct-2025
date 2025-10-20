#!/bin/bash

# Pet Adoption Auto Discovery Project - Infrastructure Destroy Script
# This script destroys Vault/Jenkins infrastructure and deletes the S3 bucket

set -euo pipefail

# Configuration variables (matching create script)
BUCKET_NAME="pet-adoption-state-bucket-1133313317711lington"
AWS_REGION="eu-west-3"  # Using same region as create script
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

# Check if jq is available for JSON processing
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_status "$RED" "❌ jq is not installed. Please install it first for JSON processing."
        exit 1
    fi
}

echo "�️ Pet Adoption Auto Discovery - Infrastructure Destruction"
echo "=========================================================="
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo ""

# Check prerequisites
check_aws_cli
check_jq
check_aws_profile

print_status "$YELLOW" "⚠️  WARNING: This will permanently destroy all infrastructure and data!"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    print_status "$BLUE" "🛑 Operation cancelled"
    exit 0
fi

echo ""

# Step 1: Destroy Vault and Jenkins infrastructure
print_status "$BLUE" "🏗️ Destroying Jenkins and Vault server infrastructure..."

if [[ ! -d "vault-jenkins" ]]; then
    print_status "$YELLOW" "⚠️  vault-jenkins directory not found, skipping Terraform destroy"
else
    cd vault-jenkins
    
    # Check if Terraform is initialized
    if [[ ! -d ".terraform" ]]; then
        print_status "$BLUE" "🔧 Initializing Terraform..."
        if terraform init; then
            print_status "$GREEN" "✅ Terraform initialized"
        else
            print_status "$RED" "❌ Terraform initialization failed"
            cd ..
            exit 1
        fi
    fi
    
    # Destroy infrastructure
    print_status "$BLUE" "💥 Destroying Terraform infrastructure..."
    if terraform destroy -auto-approve; then
        print_status "$GREEN" "✅ Infrastructure destroyed successfully"
    else
        print_status "$RED" "❌ Terraform destroy failed"
        cd ..
        exit 1
    fi
    
    # Clean up Terraform files
    print_status "$BLUE" "🧹 Cleaning up Terraform state files..."
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -rf .terraform/ 2>/dev/null || true
    
    # Security cleanup - remove any generated keys
    find . -name "*.pem" -type f -delete 2>/dev/null || true
    
    cd ..
fi

# Step 2: Delete S3 bucket
print_status "$BLUE" "🪣 Processing S3 bucket deletion..."

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null; then
    print_status "$YELLOW" "⚠️  Bucket $BUCKET_NAME not found or not accessible"
    print_status "$GREEN" "✅ S3 cleanup complete (bucket doesn't exist)"
else
    print_status "$YELLOW" "⚠️  Deleting all objects in $BUCKET_NAME. This process is irreversible..."
    
    # List all object versions and delete markers
    print_status "$BLUE" "📋 Listing all object versions and delete markers..."
    DELETE_LIST=$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json)
    
    # Extract objects to delete using jq
    OBJECTS_TO_DELETE=$(echo "$DELETE_LIST" | jq '{
        Objects: (
            [.Versions[]?, .DeleteMarkers[]?]
            | map({Key: .Key, VersionId: .VersionId})
        ),
        Quiet: true
    }')
    
    # Count number of deletable items
    NUM_OBJECTS=$(echo "$OBJECTS_TO_DELETE" | jq '.Objects | length')
    
    # Delete objects if there are any
    if [ "$NUM_OBJECTS" -gt 0 ]; then
        print_status "$BLUE" "🗑️ Deleting $NUM_OBJECTS objects from bucket: $BUCKET_NAME..."
        if aws s3api delete-objects \
            --bucket "$BUCKET_NAME" \
            --delete "$OBJECTS_TO_DELETE" \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE" > /dev/null; then
            print_status "$GREEN" "✅ Object deletion complete"
        else
            print_status "$RED" "❌ Failed to delete some objects"
        fi
    else
        print_status "$BLUE" "📭 No objects or versions found in $BUCKET_NAME"
    fi
    
    # Attempt to delete the empty bucket
    print_status "$BLUE" "🗑️ Deleting bucket: $BUCKET_NAME..."
    if aws s3api delete-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"; then
        print_status "$GREEN" "✅ Bucket $BUCKET_NAME deleted successfully"
    else
        print_status "$RED" "❌ Failed to delete bucket $BUCKET_NAME"
        exit 1
    fi
fi

# Step 3: Clean up local files
print_status "$BLUE" "🧹 Cleaning up local files..."

# Remove bucket info file
if [[ -f "bucket-info.txt" ]]; then
    rm -f bucket-info.txt
    print_status "$GREEN" "✅ Removed bucket-info.txt"
fi

# Remove any remaining sensitive files
find . -name "*.pem" -type f -delete 2>/dev/null || true
rm -f *.log 2>/dev/null || true

print_status "$GREEN" "🔒 Local cleanup completed"

echo ""
print_status "$GREEN" "🎉 Complete! All infrastructure and resources have been destroyed"
print_status "$BLUE" "📝 Summary of actions:"
echo "  ✅ Terraform infrastructure destroyed"
echo "  ✅ S3 bucket and all contents deleted"
echo "  ✅ Local state files cleaned up"
echo "  ✅ Security sensitive files removed"
echo ""
print_status "$YELLOW" "💡 Remember to:"
echo "  - Verify all resources are deleted in AWS Console"
echo "  - Check for any remaining costs in AWS Billing"
echo "  - Update any documentation or references"