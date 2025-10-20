#!/bin/bash

# Pet Adoption Auto Discovery - Production Environment Deployment Script
# Author: Fiifi Quaison
# Date: October 20, 2025
# Description: Production deployment script for Pet Adoption Auto Discovery infrastructure

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$PROJECT_ROOT/vault-jenkins"
BACKUP_DIR="$PROJECT_ROOT/backups/prod-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$PROJECT_ROOT/prod-deployment-$(date +%Y%m%d-%H%M%S).log"

# Production environment variables
export TF_VAR_environment="prod"
export TF_VAR_instance_type="t3.medium"
export TF_VAR_enable_monitoring="true"
export TF_VAR_backup_retention="30"
export AWS_DEFAULT_REGION="eu-west-3"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
    log "INFO" "$message"
}

# Error handling
error_exit() {
    print_status "$RED" "ERROR: $1"
    log "ERROR" "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    print_status "$BLUE" "🔍 Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform is not installed or not in PATH"
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed or not in PATH"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured or invalid"
    fi
    
    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        error_exit "Terraform directory not found: $TERRAFORM_DIR"
    fi
    
    print_status "$GREEN" "✅ Prerequisites check passed"
}

# Create backup
create_backup() {
    print_status "$BLUE" "📦 Creating backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup terraform state if exists
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/"
        print_status "$GREEN" "✅ Terraform state backed up"
    fi
    
    # Backup terraform configuration
    cp -r "$TERRAFORM_DIR"/*.tf "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$TERRAFORM_DIR"/*.sh "$BACKUP_DIR/" 2>/dev/null || true
    
    print_status "$GREEN" "✅ Backup created at: $BACKUP_DIR"
}

# Validate terraform configuration
validate_terraform() {
    print_status "$BLUE" "🔧 Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize terraform
    if ! terraform init; then
        error_exit "Terraform initialization failed"
    fi
    
    # Validate configuration
    if ! terraform validate; then
        error_exit "Terraform validation failed"
    fi
    
    # Format check
    if ! terraform fmt -check; then
        print_status "$YELLOW" "⚠️  Terraform files need formatting. Running terraform fmt..."
        terraform fmt
    fi
    
    print_status "$GREEN" "✅ Terraform configuration validated"
}

# Plan deployment
plan_deployment() {
    print_status "$BLUE" "📋 Planning production deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Create terraform plan
    if ! terraform plan -out=prod.tfplan; then
        error_exit "Terraform planning failed"
    fi
    
    print_status "$GREEN" "✅ Deployment plan created: prod.tfplan"
    print_status "$YELLOW" "📝 Review the plan above before proceeding with deployment"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "$BLUE" "🚀 Deploying production infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply terraform plan
    if ! terraform apply prod.tfplan; then
        error_exit "Terraform deployment failed"
    fi
    
    # Clean up plan file
    rm -f prod.tfplan
    
    print_status "$GREEN" "✅ Production infrastructure deployed successfully"
}

# Post-deployment validation
validate_deployment() {
    print_status "$BLUE" "🔍 Validating deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Get outputs
    if ! terraform output > /dev/null 2>&1; then
        error_exit "Failed to retrieve terraform outputs"
    fi
    
    # Extract IP addresses
    local jenkins_ip=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
    local vault_ip=$(terraform output -raw vault_public_ip 2>/dev/null || echo "")
    
    if [[ -n "$jenkins_ip" ]]; then
        print_status "$BLUE" "🔍 Testing Jenkins connectivity..."
        if curl -s -f -m 10 "http://$jenkins_ip:8080" > /dev/null; then
            print_status "$GREEN" "✅ Jenkins is accessible at http://$jenkins_ip:8080"
        else
            print_status "$YELLOW" "⚠️  Jenkins may still be starting up at http://$jenkins_ip:8080"
        fi
    fi
    
    if [[ -n "$vault_ip" ]]; then
        print_status "$BLUE" "🔍 Testing Vault connectivity..."
        if curl -s -f -m 10 "http://$vault_ip:8200" > /dev/null; then
            print_status "$GREEN" "✅ Vault is accessible at http://$vault_ip:8200"
        else
            print_status "$YELLOW" "⚠️  Vault may still be starting up at http://$vault_ip:8200"
        fi
    fi
    
    print_status "$GREEN" "✅ Deployment validation completed"
}

# Display deployment summary
show_summary() {
    print_status "$BLUE" "📊 Production Deployment Summary"
    echo "=================================="
    
    cd "$TERRAFORM_DIR"
    
    # Show outputs
    echo -e "\n${BLUE}Infrastructure Outputs:${NC}"
    terraform output
    
    echo -e "\n${BLUE}Deployment Details:${NC}"
    echo "• Environment: Production"
    echo "• Region: $AWS_DEFAULT_REGION"
    echo "• Backup Location: $BACKUP_DIR"
    echo "• Log File: $LOG_FILE"
    echo "• Deployment Time: $(date)"
    
    echo -e "\n${GREEN}🎉 Production deployment completed successfully!${NC}"
    
    # Show next steps
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Configure domain nameservers with Route53 nameservers"
    echo "2. Complete Jenkins initial setup"
    echo "3. Initialize and unseal Vault"
    echo "4. Set up monitoring and alerting"
    echo "5. Configure backup procedures"
}

# Cleanup function
cleanup() {
    print_status "$BLUE" "🧹 Cleaning up temporary files..."
    cd "$TERRAFORM_DIR"
    rm -f prod.tfplan
    
    # Security: Clean up any generated keys
    if ls *.pem 1> /dev/null 2>&1; then
        print_status "$YELLOW" "🔒 Cleaning up SSH keys for security..."
        rm -f *.pem
    fi
    
    print_status "$GREEN" "✅ Cleanup completed"
}

# State recovery function
recover_state() {
    print_status "$YELLOW" "🔄 Attempting to recover Terraform state..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if state file exists but is empty or corrupted
    if [[ -f "terraform.tfstate" ]]; then
        local state_size=$(wc -c < terraform.tfstate)
        if [[ $state_size -lt 100 ]]; then
            print_status "$YELLOW" "⚠️  State file appears corrupted or empty"
            # Backup the corrupted state
            mv terraform.tfstate terraform.tfstate.corrupted.$(date +%s)
        fi
    fi
    
    # Try to refresh state
    if terraform refresh; then
        print_status "$GREEN" "✅ State recovery successful"
        return 0
    else
        print_status "$YELLOW" "⚠️  State refresh failed - will proceed with manual cleanup if needed"
        return 1
    fi
}

# Enhanced destroy function with fallback cleanup
destroy_environment() {
    print_status "$YELLOW" "⚠️  Destroying production environment..."
    
    cd "$TERRAFORM_DIR"
    
    echo -e "\n${RED}⚠️  You are about to DESTROY the PRODUCTION environment.${NC}"
    echo -e "${RED}This will remove ALL AWS resources created by this project.${NC}"
    echo -e "${RED}This action cannot be undone!${NC}"
    read -p "Type 'destroy-production' to confirm: " confirm
    
    if [[ "$confirm" != "destroy-production" ]]; then
        print_status "$YELLOW" "❌ Destruction cancelled"
        exit 0
    fi
    
    # Attempt normal terraform destroy first
    print_status "$BLUE" "🔍 Attempting Terraform destroy..."
    
    if terraform destroy -auto-approve; then
        print_status "$GREEN" "✅ Production environment destroyed successfully via Terraform"
        # Clean up state files
        rm -f terraform.tfstate terraform.tfstate.backup
        return 0
    else
        print_status "$YELLOW" "⚠️  Terraform destroy failed, attempting manual cleanup..."
        
        # Try state recovery first
        if ! recover_state; then
            print_status "$YELLOW" "🧹 Running comprehensive manual cleanup..."
            
            # Run the comprehensive cleanup script
            local cleanup_script="$PROJECT_ROOT/destroy-s3-bucket.sh"
            if [[ -f "$cleanup_script" ]]; then
                bash "$cleanup_script"
            else
                print_status "$RED" "❌ Cleanup script not found. Manual AWS resource cleanup required."
                print_status "$YELLOW" "Please check AWS console and delete resources manually:"
                print_status "$YELLOW" "1. EC2 instances with Project tag 'Fiifi-Pet-Adoption-Auto-Discovery'"
                print_status "$YELLOW" "2. VPCs, subnets, security groups"
                print_status "$YELLOW" "3. Load balancers and Route53 records"
                print_status "$YELLOW" "4. IAM roles and instance profiles"
                return 1
            fi
        fi
        
        # Clean up local state regardless
        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
        rm -rf .terraform/
        
        # Clean up generated keys for security
        rm -f *.pem
        
        print_status "$GREEN" "✅ Manual cleanup completed"
        print_status "$GREEN" "🔒 SSH keys cleaned up for security"
    fi
}

# Main deployment function
main() {
    print_status "$GREEN" "🚀 Starting Pet Adoption Auto Discovery Production Deployment"
    print_status "$BLUE" "📅 Date: $(date)"
    print_status "$BLUE" "📍 Region: $AWS_DEFAULT_REGION"
    
    # Security warning
    print_status "$YELLOW" "🔒 SECURITY NOTICE: SSH keys will be generated locally"
    print_status "$YELLOW" "🔒 Keys are NOT committed to git (protected by .gitignore)"
    print_status "$YELLOW" "🔒 Keys will be cleaned up during destroy operations"
    
    # Create log file
    touch "$LOG_FILE"
    
    # Run deployment steps
    check_prerequisites
    create_backup
    validate_terraform
    plan_deployment
    
    # Confirm deployment
    echo -e "\n${YELLOW}⚠️  You are about to deploy to PRODUCTION environment.${NC}"
    echo -e "${YELLOW}This will create AWS resources that may incur costs.${NC}"
    read -p "Do you want to proceed with the deployment? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_status "$YELLOW" "❌ Deployment cancelled by user"
        cleanup
        exit 0
    fi
    
    deploy_infrastructure
    validate_deployment
    show_summary
    cleanup
    
    print_status "$GREEN" "🎉 Production deployment completed successfully!"
}

# Script usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo "Pet Adoption Auto Discovery - Production Environment Deployment"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --version   Show version information"
    echo "  -d, --dry-run   Plan only, do not deploy"
    echo "  -x, --destroy   Destroy production environment"
    echo "  -r, --recover   Recover corrupted Terraform state"
    echo ""
    echo "Examples:"
    echo "  $0               # Run full production deployment"
    echo "  $0 --dry-run     # Plan deployment without applying"
    echo "  $0 --destroy     # Destroy production environment"
    echo "  $0 --recover     # Recover Terraform state"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "Pet Adoption Auto Discovery Production Deployment v1.0"
            echo "Author: Fiifi Quaison"
            echo "Date: October 20, 2025"
            exit 0
            ;;
        -d|--dry-run)
            print_status "$YELLOW" "🔍 Running in dry-run mode (plan only)"
            check_prerequisites
            create_backup
            validate_terraform
            plan_deployment
            cleanup
            print_status "$GREEN" "✅ Dry-run completed"
            exit 0
            ;;
        -x|--destroy)
            check_prerequisites
            destroy_environment
            exit 0
            ;;
        -r|--recover)
            check_prerequisites
            recover_state
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main