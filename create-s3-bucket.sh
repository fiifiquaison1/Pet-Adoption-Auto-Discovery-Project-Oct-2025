#!/bin/bash

# Pet Adoption Auto Discovery Project - Automated S3 Bucket Creation & Deployment
# Fully non-interactive version

set -euo pipefail

# --- CONFIGURATION ---
BUCKET_NAME="auto-discovery-fiifi-86"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"
PROJECT_TAG="Fiifi-Pet-Adoption-Auto-Discovery"
LOG_FILE="create.log"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- HELPERS ---
print_status() { echo -e "${1}${2}${NC}"; }
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

echo "🪣 Pet Adoption Auto Discovery - S3 + Jenkins/Vault Setup"
echo "=========================================================="
print_status "$BLUE" "Bucket: $BUCKET_NAME | Region: $AWS_REGION | Profile: $AWS_PROFILE"
echo ""

# --- PREREQUISITE CHECKS ---
if ! command -v aws &>/dev/null; then
  print_status "$RED" "❌ AWS CLI not installed. Install AWS CLI v2 first."
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  print_status "$RED" "❌ Terraform not installed. Please install Terraform."
  exit 1
fi

if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
  print_status "$YELLOW" "⚠️ AWS profile '${AWS_PROFILE}' not found, defaulting to 'default'"
  AWS_PROFILE="default"
fi

# --- S3 BUCKET CREATION ---
print_status "$BLUE" "📦 Creating or verifying S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
  print_status "$GREEN" "✅ S3 bucket exists: $BUCKET_NAME"
else
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"
  else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  print_status "$GREEN" "✅ S3 bucket created: $BUCKET_NAME"
fi

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --versioning-configuration Status=Enabled
print_status "$GREEN" "✅ Versioning enabled"

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
print_status "$GREEN" "✅ Public access blocked"

# Tag bucket
aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE" \
  --tagging "TagSet=[
    {Key=Project,Value=$PROJECT_TAG},
    {Key=Environment,Value=shared},
    {Key=ManagedBy,Value=Script},
    {Key=Purpose,Value=TerraformState}
  ]"
print_status "$GREEN" "✅ Tags applied to bucket"



# --- SAVE CONFIGURATION ---
cat > bucket-info.txt <<EOF
# Pet Adoption Auto Discovery - Terraform Backend Info
BUCKET_NAME=$BUCKET_NAME
AWS_REGION=$AWS_REGION
AWS_PROFILE=$AWS_PROFILE
PROJECT_TAG=$PROJECT_TAG
EOF
print_status "$GREEN" "💾 Saved configuration: bucket-info.txt"

# --- DEPLOY INFRASTRUCTURE ---
if [[ ! -d "vault-jenkins" ]]; then
  print_status "$RED" "❌ vault-jenkins directory not found."
  exit 1
fi

cd vault-jenkins

print_status "$BLUE" "🔧 Initializing Terraform..."
terraform init -reconfigure \
               -backend-config="bucket=$BUCKET_NAME" \
               -backend-config="key=terraform.tfstate" \
               -backend-config="region=$AWS_REGION" \
               -backend-config="profile=$AWS_PROFILE"

print_status "$BLUE" "🔍 Validating Terraform configuration..."
terraform validate

print_status "$BLUE" "🚀 Applying Terraform deployment (auto-approved)..."
terraform apply -auto-approve

print_status "$GREEN" "🎉 Deployment completed successfully!"
print_status "$BLUE" "📊 Terraform Outputs:"
terraform output || true

cd ..

print_status "$GREEN" "✅ All steps completed successfully!"
print_status "$BLUE" "📝 Logs stored in: $LOG_FILE"
