#!/bin/bash

# Pet Adoption Auto Discovery Project - S3 Bucket Creation Script
# This script creates an S3 bucket for storing pet adoption data and resources

set -e  # Exit on any error

# Configuration variables
PROJECT_NAME="fiifi-pet-adoption-auto-discovery"
BUCKET_NAME="${PROJECT_NAME}-$(date +%Y%m%d)-$(openssl rand -hex 4)"
REGION="us-east-1"
ENVIRONMENT="dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    print_success "AWS CLI is installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS credentials are configured"
}

# Function to create S3 bucket
create_s3_bucket() {
    print_status "Creating S3 bucket: $BUCKET_NAME"
    
    # Create the bucket
    if aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || \
       aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" 2>/dev/null; then
        
        print_success "S3 bucket '$BUCKET_NAME' created successfully"
    else
        print_error "Failed to create S3 bucket"
        exit 1
    fi
}

# Function to configure bucket settings
configure_bucket() {
    print_status "Configuring bucket settings..."
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    print_success "Public access blocked for security"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    print_success "Versioning enabled"
    
    # Add tags
    aws s3api put-bucket-tagging \
        --bucket "$BUCKET_NAME" \
        --tagging 'TagSet=[
            {Key=Project,Value=FiifiPetAdoptionAutoDiscovery},
            {Key=Environment,Value='$ENVIRONMENT'},
            {Key=Owner,Value=fiifiquaison1},
            {Key=Purpose,Value=PetDataStorage},
            {Key=CreatedDate,Value='$(date +%Y-%m-%d)'}
        ]'
    
    print_success "Tags applied to bucket"
}

# Function to create folder structure
create_folder_structure() {
    print_status "Creating folder structure..."
    
    # Create folders for different types of data
    aws s3api put-object --bucket "$BUCKET_NAME" --key "pet-images/" --content-length 0
    aws s3api put-object --bucket "$BUCKET_NAME" --key "pet-data/" --content-length 0
    aws s3api put-object --bucket "$BUCKET_NAME" --key "adoption-records/" --content-length 0
    aws s3api put-object --bucket "$BUCKET_NAME" --key "logs/" --content-length 0
    aws s3api put-object --bucket "$BUCKET_NAME" --key "backups/" --content-length 0
    
    print_success "Folder structure created"
}

# Function to save bucket info
save_bucket_info() {
    print_status "Saving bucket information..."
    
    # Create a bucket info file
    cat > bucket-info.txt << EOF
# Fiifi Pet Adoption Auto Discovery Project - S3 Bucket Information
# Generated on: $(date)

BUCKET_NAME=$BUCKET_NAME
BUCKET_REGION=$REGION
BUCKET_ARN=arn:aws:s3:::$BUCKET_NAME
PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT
CREATED_DATE=$(date +%Y-%m-%d)

# Folder Structure:
# - pet-images/     : Store pet photos and media
# - pet-data/       : Store pet information and metadata
# - adoption-records/: Store adoption forms and records
# - logs/           : Store application logs
# - backups/        : Store backup files

# Usage Examples:
# Upload a pet image: aws s3 cp pet_photo.jpg s3://$BUCKET_NAME/pet-images/
# List bucket contents: aws s3 ls s3://$BUCKET_NAME/
# Sync local folder: aws s3 sync ./local-folder s3://$BUCKET_NAME/pet-data/
EOF
    
    print_success "Bucket information saved to bucket-info.txt"
}

# Main execution
main() {
    print_status "Starting S3 bucket creation for Fiifi Pet Adoption Auto Discovery Project"
    print_status "=========================================="
    
    # Check prerequisites
    check_aws_cli
    check_aws_credentials
    
    # Create and configure bucket
    create_s3_bucket
    configure_bucket
    create_folder_structure
    save_bucket_info
    
    print_status "=========================================="
    print_success "S3 bucket setup completed successfully!"
    print_status "Bucket Name: $BUCKET_NAME"
    print_status "Region: $REGION"
    print_status "Bucket ARN: arn:aws:s3:::$BUCKET_NAME"
    print_warning "Save the bucket name for future reference!"
    print_status "Bucket information has been saved to bucket-info.txt"
}

# Execute main function
main "$@"