#!/bin/bash

# Terraform State Management Script
# This script provides utilities for managing Terraform state

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/vault-jenkins"

print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Backup current state
backup_state() {
    local backup_dir="$SCRIPT_DIR/state-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$backup_dir/"
        print_status "$GREEN" "✅ State backed up to: $backup_dir"
    else
        print_status "$YELLOW" "⚠️  No state file found to backup"
    fi
    
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate.backup" ]]; then
        cp "$TERRAFORM_DIR/terraform.tfstate.backup" "$backup_dir/"
    fi
}

# Import existing resources into state
import_resources() {
    print_status "$BLUE" "🔄 Attempting to import existing resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize terraform if not done
    terraform init -upgrade
    
    # Try to import common resources that might exist
    # This is a manual process and would need specific resource IDs
    print_status "$YELLOW" "⚠️  Manual import required. Use the following commands if resources exist:"
    echo ""
    echo "terraform import aws_vpc.vpc vpc-XXXXXXXXX"
    echo "terraform import aws_instance.jenkins-server i-XXXXXXXXX"
    echo "terraform import aws_instance.vault i-XXXXXXXXX"
    echo ""
    print_status "$YELLOW" "Replace XXXXXXXXX with actual resource IDs from AWS console"
}

# Validate state
validate_state() {
    print_status "$BLUE" "🔍 Validating Terraform state..."
    
    cd "$TERRAFORM_DIR"
    
    if [[ ! -f "terraform.tfstate" ]]; then
        print_status "$RED" "❌ No state file found"
        return 1
    fi
    
    local state_size=$(wc -c < terraform.tfstate)
    if [[ $state_size -lt 100 ]]; then
        print_status "$RED" "❌ State file appears corrupted (too small)"
        return 1
    fi
    
    # Try to refresh state
    if terraform refresh -input=false; then
        print_status "$GREEN" "✅ State is valid and refreshed"
        return 0
    else
        print_status "$RED" "❌ State validation failed"
        return 1
    fi
}

# Clean corrupted state
clean_state() {
    print_status "$YELLOW" "🧹 Cleaning corrupted state..."
    
    # Backup first
    backup_state
    
    cd "$TERRAFORM_DIR"
    
    # Remove corrupted files
    rm -f terraform.tfstate terraform.tfstate.backup
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    
    print_status "$GREEN" "✅ State cleaned. Run 'terraform init' to reinitialize."
}

# Show state statistics
show_state_info() {
    cd "$TERRAFORM_DIR"
    
    if [[ -f "terraform.tfstate" ]]; then
        print_status "$BLUE" "📊 State Information:"
        echo "• State file size: $(ls -lh terraform.tfstate | awk '{print $5}')"
        echo "• Last modified: $(date -r terraform.tfstate)"
        
        local resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
        echo "• Resources in state: $resource_count"
        
        if [[ $resource_count -gt 0 ]]; then
            echo ""
            print_status "$BLUE" "📝 Resources in state:"
            terraform state list || true
        fi
    else
        print_status "$YELLOW" "⚠️  No state file found"
    fi
}

# Usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo "Terraform State Management Utility"
    echo ""
    echo "Commands:"
    echo "  backup      Backup current state"
    echo "  validate    Validate current state"
    echo "  import      Show import commands for existing resources"
    echo "  clean       Clean corrupted state files"
    echo "  info        Show state information"
    echo "  help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 backup     # Backup current state"
    echo "  $0 validate   # Check if state is valid"
    echo "  $0 clean      # Clean corrupted state"
}

# Main function
main() {
    case "${1:-help}" in
        backup)
            backup_state
            ;;
        validate)
            validate_state
            ;;
        import)
            import_resources
            ;;
        clean)
            echo -e "${RED}⚠️  This will remove all state files!${NC}"
            read -p "Type 'clean' to confirm: " confirm
            if [[ "$confirm" == "clean" ]]; then
                clean_state
            else
                print_status "$YELLOW" "❌ Operation cancelled"
            fi
            ;;
        info)
            show_state_info
            ;;
        help|*)
            usage
            ;;
    esac
}

main "$@"