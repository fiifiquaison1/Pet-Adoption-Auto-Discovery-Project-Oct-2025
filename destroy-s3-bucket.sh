#!/bin/bash

# Fiifi Pet Adoption Auto Discovery Project - S3 Bucket Destruction Script
# This script safely destroys the S3 bucket and all its contents

set -e  # Exit on any error

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [BUCKET_NAME]"
    echo ""
    echo "Options:"
    echo "  BUCKET_NAME    Specify the bucket name directly"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 my-bucket-name                     # Destroy specific bucket"
    echo "  $0 my-bucket-name --force             # Force destroy without confirmation"
    echo ""
    echo "If no bucket name is provided, the script will try to read from bucket-info.txt"
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

# Function to get bucket name from bucket-info.txt
get_bucket_from_info_file() {
    if [[ -f "bucket-info.txt" ]]; then
        BUCKET_NAME=$(grep "BUCKET_NAME=" bucket-info.txt | cut -d'=' -f2)
        if [[ -n "$BUCKET_NAME" ]]; then
            print_status "Found bucket name in bucket-info.txt: $BUCKET_NAME"
            return 0
        fi
    fi
    return 1
}

# Function to prompt for bucket name
prompt_for_bucket_name() {
    while [[ -z "$BUCKET_NAME" ]]; do
        read -p "Enter the S3 bucket name to destroy: " BUCKET_NAME
        if [[ -z "$BUCKET_NAME" ]]; then
            print_warning "Bucket name cannot be empty. Please try again."
        fi
    done
}

# Function to check if bucket exists
check_bucket_exists() {
    print_status "Checking if bucket '$BUCKET_NAME' exists..."
    
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        print_success "Bucket '$BUCKET_NAME' exists"
        return 0
    else
        print_error "Bucket '$BUCKET_NAME' does not exist or you don't have access to it"
        return 1
    fi
}

# Function to show bucket information
show_bucket_info() {
    print_status "Bucket Information:"
    echo "===================="
    
    # Get bucket region
    REGION=$(aws s3api get-bucket-location --bucket "$BUCKET_NAME" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
    if [[ "$REGION" == "None" || "$REGION" == "null" ]]; then
        REGION="us-east-1"
    fi
    
    echo "Bucket Name: $BUCKET_NAME"
    echo "Region: $REGION"
    echo "ARN: arn:aws:s3:::$BUCKET_NAME"
    
    # Get object count and size
    print_status "Analyzing bucket contents..."
    OBJECT_COUNT=$(aws s3 ls s3://"$BUCKET_NAME" --recursive --summarize 2>/dev/null | grep "Total Objects:" | awk '{print $3}' || echo "0")
    TOTAL_SIZE=$(aws s3 ls s3://"$BUCKET_NAME" --recursive --summarize --human-readable 2>/dev/null | grep "Total Size:" | awk '{print $3 " " $4}' || echo "0 Bytes")
    
    echo "Total Objects: $OBJECT_COUNT"
    echo "Total Size: $TOTAL_SIZE"
    
    # Show tags if any
    print_status "Bucket tags:"
    aws s3api get-bucket-tagging --bucket "$BUCKET_NAME" --query 'TagSet[*].[Key,Value]' --output table 2>/dev/null || echo "No tags found"
    
    echo "===================="
}

# Function to create backup before deletion
create_backup() {
    if [[ "$FORCE_MODE" != "true" ]]; then
        read -p "Do you want to create a backup of the bucket contents before deletion? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)-$BUCKET_NAME"
            print_status "Creating backup in $BACKUP_DIR..."
            
            mkdir -p "$BACKUP_DIR"
            aws s3 sync s3://"$BUCKET_NAME" "$BACKUP_DIR" --delete
            
            print_success "Backup created in $BACKUP_DIR"
        fi
    fi
}

# Function to empty the bucket
empty_bucket() {
    print_status "Emptying bucket '$BUCKET_NAME'..."
    
    # Delete all objects and versions
    aws s3 rm s3://"$BUCKET_NAME" --recursive
    
    # Delete all object versions and delete markers (for versioned buckets)
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" \
        --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}, Quiet: true}' \
        --output json)" 2>/dev/null || true
    
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" \
        --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}, Quiet: true}' \
        --output json)" 2>/dev/null || true
    
    print_success "Bucket emptied successfully"
}

# Function to delete the bucket
delete_bucket() {
    print_status "Deleting bucket '$BUCKET_NAME'..."
    
    if aws s3api delete-bucket --bucket "$BUCKET_NAME"; then
        print_success "Bucket '$BUCKET_NAME' deleted successfully"
    else
        print_error "Failed to delete bucket '$BUCKET_NAME'"
        exit 1
    fi
}

# Function to cleanup local files
cleanup_local_files() {
    if [[ -f "bucket-info.txt" ]]; then
        if [[ "$FORCE_MODE" != "true" ]]; then
            read -p "Do you want to delete the local bucket-info.txt file? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm bucket-info.txt
                print_success "Local bucket-info.txt file deleted"
            fi
        else
            rm bucket-info.txt
            print_success "Local bucket-info.txt file deleted"
        fi
    fi
}

# Function to confirm destruction
confirm_destruction() {
    if [[ "$FORCE_MODE" == "true" ]]; then
        return 0
    fi
    
    print_warning "⚠️  WARNING: This action will PERMANENTLY delete the S3 bucket and ALL its contents!"
    print_warning "This action CANNOT be undone!"
    echo ""
    read -p "Are you absolutely sure you want to destroy bucket '$BUCKET_NAME'? (yes/NO): " -r
    
    if [[ $REPLY == "yes" ]]; then
        print_warning "Last chance! Type the bucket name to confirm: $BUCKET_NAME"
        read -p "Bucket name: " -r CONFIRM_BUCKET
        
        if [[ "$CONFIRM_BUCKET" == "$BUCKET_NAME" ]]; then
            return 0
        else
            print_error "Bucket name doesn't match. Aborting."
            exit 1
        fi
    else
        print_status "Operation cancelled by user"
        exit 0
    fi
}

# Parse command line arguments
BUCKET_NAME=""
FORCE_MODE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -f|--force)
            FORCE_MODE="true"
            shift
            ;;
        -*)
            print_error "Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$BUCKET_NAME" ]]; then
                BUCKET_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Main execution
main() {
    print_status "Starting S3 bucket destruction for Fiifi Pet Adoption Auto Discovery Project"
    print_status "=========================================="
    
    # Check prerequisites
    check_aws_cli
    check_aws_credentials
    
    # Get bucket name
    if [[ -z "$BUCKET_NAME" ]]; then
        if ! get_bucket_from_info_file; then
            prompt_for_bucket_name
        fi
    fi
    
    # Validate bucket exists
    if ! check_bucket_exists; then
        exit 1
    fi
    
    # Show bucket information
    show_bucket_info
    
    # Confirm destruction
    confirm_destruction
    
    # Create backup if requested
    create_backup
    
    # Perform destruction
    empty_bucket
    delete_bucket
    cleanup_local_files
    
    print_status "=========================================="
    print_success "S3 bucket '$BUCKET_NAME' has been completely destroyed!"
    print_warning "Remember: This action is irreversible!"
}

# Execute main function
main "$@"