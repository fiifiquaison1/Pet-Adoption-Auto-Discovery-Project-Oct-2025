#!/bin/bash

# Pet Adoption Auto Discovery Project - Infrastructure Destroy Script
# This script destroys Vault/Jenkins infrastructure and deletes the S3 bucket

set -euo pipefail

# ============================================
# Configuration variables
# ============================================
BUCKET_NAME="auto-discovery-fiifi-86"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"
PROJECT_TAG="Fiifi-Pet-Adoption-Auto-Discovery"

# Auto-confirm destruction (set to true to skip prompt)
AUTO_CONFIRM="${AUTO_CONFIRM:-false}"

# ============================================
# Color codes
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${1}${2}${NC}"
}

# ============================================
# Checks
# ============================================
check_aws_profile() {
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        print_status "$YELLOW" "⚠️  AWS profile '${AWS_PROFILE}' not found, using default profile"
        AWS_PROFILE="default"
    fi
}

check_aws_cli() {
    if ! command -v aws &>/dev/null; then
        print_status "$RED" "❌ AWS CLI not installed."
        exit 1
    fi
}

check_jq() {
    if ! command -v jq &>/dev/null; then
        print_status "$RED" "❌ jq not installed."
        exit 1
    fi
}

# ============================================
# Start
# ============================================
echo "🗑️ Pet Adoption Auto Discovery - Infrastructure Destruction"
echo "=========================================================="

# Load actual bucket info if available
if [[ -f "bucket-info.txt" ]]; then
    print_status "$BLUE" "📋 Loading bucket configuration from bucket-info.txt..."
    source bucket-info.txt
    print_status "$GREEN" "✅ Loaded configuration: $BUCKET_NAME in $AWS_REGION"
fi

echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo ""

check_aws_cli
check_jq
check_aws_profile

# ============================================
# Confirm destruction
# ============================================
if [[ "$AUTO_CONFIRM" != "true" ]]; then
    print_status "$YELLOW" "⚠️  WARNING: This will permanently destroy all infrastructure and data!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_status "$BLUE" "🛑 Operation cancelled"
        exit 0
    fi
else
    print_status "$BLUE" "⚙️  Auto-confirm enabled. Proceeding without prompt..."
fi

echo ""

# ============================================
# Step 1: Destroy Terraform infrastructure
# ============================================
print_status "$BLUE" "🏗️ Destroying Jenkins and Vault server infrastructure..."

if [[ -d "vault-jenkins" ]]; then
    cd vault-jenkins
    if [[ ! -d ".terraform" ]]; then
        print_status "$BLUE" "🔧 Initializing Terraform..."
        terraform init
    fi
    print_status "$BLUE" "💥 Running Terraform destroy..."
    terraform destroy -auto-approve
    rm -f terraform.tfstate* .terraform.lock.hcl
    rm -rf .terraform/
    find . -name "*.pem" -delete 2>/dev/null || true
    cd ..
else
    print_status "$YELLOW" "⚠️  vault-jenkins directory not found, skipping Terraform destroy"
fi

# ============================================
# Step 2: Delete S3 bucket
# ============================================
print_status "$BLUE" "🪣 Processing S3 bucket deletion..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
    print_status "$YELLOW" "⚠️  Deleting all versions and markers in bucket..."
    DELETE_LIST=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json --region "$AWS_REGION" --profile "$AWS_PROFILE")
    OBJECTS_TO_DELETE=$(echo "$DELETE_LIST" | jq '{
        Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key: .Key, VersionId: .VersionId})),
        Quiet: true
    }')
    NUM_OBJECTS=$(echo "$OBJECTS_TO_DELETE" | jq '.Objects | length')

    if [[ "$NUM_OBJECTS" -gt 0 ]]; then
        aws s3api delete-objects --bucket "$BUCKET_NAME" --delete "$OBJECTS_TO_DELETE" --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null
        print_status "$GREEN" "✅ Deleted $NUM_OBJECTS objects"
    fi

    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    print_status "$GREEN" "✅ Bucket $BUCKET_NAME deleted successfully"
else
    print_status "$YELLOW" "⚠️  Bucket not found, skipping deletion"
fi

# ============================================
# Step 3: Local cleanup
# ============================================
print_status "$BLUE" "🧹 Cleaning up local files..."
rm -f bucket-info.txt *.log 2>/dev/null || true
find . -name "*.pem" -delete 2>/dev/null || true
print_status "$GREEN" "🔒 Local cleanup completed"

echo ""
print_status "$GREEN" "🎉 Complete! All infrastructure and resources destroyed successfully."
print_status "$BLUE" "📝 Summary:"
echo "  ✅ Terraform infrastructure destroyed"
echo "  ✅ S3 bucket and contents deleted"
echo "  ✅ Local files cleaned up"
echo ""
print_status "$YELLOW" "💡 Tip: Run with 'AUTO_CONFIRM=true' to skip confirmation automatically."
