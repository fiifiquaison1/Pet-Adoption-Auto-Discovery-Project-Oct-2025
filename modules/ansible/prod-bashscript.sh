#!/bin/bash

# Pet Adoption Auto Discovery Project - Production Ansible Deployment Script
# Author: Fiifi Quaison
# Description: Automated deployment and container management for production environment
# CRITICAL: This script manages production infrastructure - handle with care!

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Production configuration variables
AWS_CLI_PATH='/usr/local/bin/aws'
INVENTORY_FILE='/etc/ansible/production_hosts'
IPS_FILE='/etc/ansible/production_ips.list'
ASG_NAME='fiifi-pet-adoption-prod-asg'
SSH_KEY_PATH='/home/ec2-user/.ssh/fiifi-pet-adoption-key.pem'
WAIT_TIME=60  # Longer wait time for production
ANSIBLE_USER='ec2-user'
CONTAINER_NAME='pet-adoption-app'
STARTUP_SCRIPT_PATH='/home/ec2-user/scripts/start-container.sh'
LOG_FILE="/var/log/ansible-prod-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/var/backups/ansible/$(date +%Y%m%d-%H%M%S)"

# Production-specific settings
MAX_RETRIES=3
HEALTH_CHECK_TIMEOUT=120
DEPLOYMENT_CONFIRMATION=true

# Logging function with enhanced production logging
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] [PROD] [$level]${NC} $message" | tee -a "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}✅ [PROD] $message${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}❌ [PROD] CRITICAL ERROR: $message${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  [PROD] WARNING: $message${NC}" | tee -a "$LOG_FILE"
}

# Production confirmation prompt
confirm_production_deployment() {
    if [[ "$DEPLOYMENT_CONFIRMATION" == "true" ]]; then
        echo ""
        echo -e "${RED}⚠️  PRODUCTION DEPLOYMENT WARNING${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "${YELLOW}You are about to deploy to PRODUCTION environment.${NC}"
        echo -e "${YELLOW}This will affect live services and user traffic.${NC}"
        echo ""
        echo "ASG: $ASG_NAME"
        echo "Container: $CONTAINER_NAME"
        echo "Environment: PRODUCTION"
        echo ""
        read -p "Do you want to proceed? Type 'DEPLOY-PRODUCTION' to confirm: " confirm
        
        if [[ "$confirm" != "DEPLOY-PRODUCTION" ]]; then
            log_warning "Production deployment cancelled by user"
            exit 0
        fi
        
        log_message "INFO" "Production deployment confirmed by user"
    fi
}

# Create backup of current state
create_backup() {
    log_message "INFO" "Creating production state backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup current inventory if exists
    if [[ -f "$INVENTORY_FILE" ]]; then
        cp "$INVENTORY_FILE" "$BACKUP_DIR/inventory_backup.txt"
        log_success "Current inventory backed up"
    fi
    
    # Backup current IPs if exists
    if [[ -f "$IPS_FILE" ]]; then
        cp "$IPS_FILE" "$BACKUP_DIR/ips_backup.txt"
        log_success "Current IPs list backed up"
    fi
    
    log_success "Backup created at: $BACKUP_DIR"
}

# Fetch instance IPs from Auto Scaling Group with retry logic
fetch_instance_ips() {
    log_message "INFO" "Fetching production instance IPs from ASG: $ASG_NAME"
    
    if ! command -v "$AWS_CLI_PATH" &> /dev/null; then
        log_error "AWS CLI not found at $AWS_CLI_PATH"
        return 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$IPS_FILE")"
    
    local retry_count=0
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        if $AWS_CLI_PATH ec2 describe-instances \
            --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
            --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress' \
            --output text > "$IPS_FILE"; then
            
            local ip_count=$(wc -l < "$IPS_FILE")
            if [[ $ip_count -gt 0 ]]; then
                log_success "Found $ip_count production instance(s) in ASG"
                return 0
            else
                log_warning "No instances found in ASG (attempt $((retry_count + 1))/$MAX_RETRIES)"
            fi
        else
            log_warning "Failed to fetch instance IPs (attempt $((retry_count + 1))/$MAX_RETRIES)"
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $MAX_RETRIES ]]; then
            log_message "INFO" "Retrying in 10 seconds..."
            sleep 10
        fi
    done
    
    log_error "Failed to fetch instance IPs after $MAX_RETRIES attempts"
    return 1
}

# Update Ansible inventory file with production-specific settings
update_ansible_inventory() {
    log_message "INFO" "Updating production Ansible inventory: $INVENTORY_FILE"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$INVENTORY_FILE")"
    
    # Check if IPs file exists and has content
    if [[ ! -f "$IPS_FILE" ]] || [[ ! -s "$IPS_FILE" ]]; then
        log_error "IPs file is empty or doesn't exist: $IPS_FILE"
        return 1
    fi
    
    # Create inventory header with production-specific configuration
    cat > "$INVENTORY_FILE" << EOF
# Pet Adoption Auto Discovery - PRODUCTION Environment Inventory
# Generated on: $(date)
# WARNING: This file contains production server configurations

[production_webservers]
EOF
    
    local added_count=0
    
    # Add each instance to inventory and known_hosts
    while IFS= read -r instance_ip; do
        if [[ -n "$instance_ip" && "$instance_ip" != "None" ]]; then
            log_message "INFO" "Adding production instance to inventory: $instance_ip"
            
            # Add to known_hosts to avoid SSH prompts
            if ssh-keyscan -H "$instance_ip" >> ~/.ssh/known_hosts 2>/dev/null; then
                log_success "Added $instance_ip to known_hosts"
            else
                log_warning "Failed to add $instance_ip to known_hosts"
            fi
            
            # Add to inventory with production-specific settings
            cat >> "$INVENTORY_FILE" << EOF
$instance_ip ansible_user=$ANSIBLE_USER ansible_ssh_private_key_file=$SSH_KEY_PATH ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectTimeout=30'
EOF
            added_count=$((added_count + 1))
        fi
    done < "$IPS_FILE"
    
    if [[ $added_count -gt 0 ]]; then
        log_success "Production Ansible inventory updated with $added_count instances"
        return 0
    else
        log_error "No valid instances added to inventory"
        return 1
    fi
}

# Extended wait for production instances
wait_for_production_instances() {
    log_message "INFO" "Waiting $WAIT_TIME seconds for production instances to be ready..."
    log_warning "Extended wait time for production stability"
    
    local countdown=$WAIT_TIME
    while [[ $countdown -gt 0 ]]; do
        if [[ $((countdown % 15)) -eq 0 ]]; then
            log_message "INFO" "$countdown seconds remaining..."
        fi
        sleep 1
        countdown=$((countdown - 1))
    done
    
    log_success "Production wait period completed"
}

# Enhanced container management with health checks
manage_production_containers() {
    log_message "INFO" "Managing Docker containers on production instances..."
    
    if [[ ! -f "$IPS_FILE" ]] || [[ ! -s "$IPS_FILE" ]]; then
        log_error "No production instances found to manage"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    local failed_instances=()
    
    while IFS= read -r instance_ip; do
        if [[ -n "$instance_ip" && "$instance_ip" != "None" ]]; then
            total_count=$((total_count + 1))
            log_message "INFO" "Checking container on production instance: $instance_ip"
            
            # Check if container is running with health check
            if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
                "$ANSIBLE_USER@$instance_ip" \
                "docker ps --filter name=$CONTAINER_NAME --filter status=running --format '{{.Names}}' | grep -q $CONTAINER_NAME" 2>/dev/null; then
                
                # Additional health check
                if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
                    "$ANSIBLE_USER@$instance_ip" \
                    "docker exec $CONTAINER_NAME curl -f http://localhost:8080/health || echo 'Health check failed'" 2>/dev/null | grep -q "Health check failed"; then
                    
                    log_warning "Container '$CONTAINER_NAME' running but health check failed on $instance_ip"
                else
                    log_success "Container '$CONTAINER_NAME' is healthy on $instance_ip"
                    success_count=$((success_count + 1))
                    continue
                fi
            fi
            
            log_warning "Container '$CONTAINER_NAME' needs attention on $instance_ip"
            
            # Attempt to start/restart the container
            log_message "INFO" "Deploying container on $instance_ip..."
            if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
                "$ANSIBLE_USER@$instance_ip" \
                "bash $STARTUP_SCRIPT_PATH" 2>/dev/null; then
                
                # Wait and verify deployment
                log_message "INFO" "Verifying deployment on $instance_ip..."
                sleep 30
                
                if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
                    "$ANSIBLE_USER@$instance_ip" \
                    "docker ps --filter name=$CONTAINER_NAME --filter status=running --format '{{.Names}}' | grep -q $CONTAINER_NAME" 2>/dev/null; then
                    
                    log_success "Container successfully deployed on $instance_ip"
                    success_count=$((success_count + 1))
                else
                    log_error "Container deployment verification failed on $instance_ip"
                    failed_instances+=("$instance_ip")
                fi
            else
                log_error "Failed to deploy container on $instance_ip"
                failed_instances+=("$instance_ip")
            fi
        fi
    done < "$IPS_FILE"
    
    # Production deployment summary
    log_message "INFO" "Production container management completed"
    log_message "INFO" "Success: $success_count/$total_count instances"
    
    if [[ ${#failed_instances[@]} -gt 0 ]]; then
        log_error "Failed instances: ${failed_instances[*]}"
        return 1
    else
        log_success "All production instances successfully managed"
        return 0
    fi
}

# Enhanced validation for production
validate_production_prerequisites() {
    log_message "INFO" "Validating production prerequisites..."
    
    # Check SSH key exists and has correct permissions
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH key not found: $SSH_KEY_PATH"
        return 1
    fi
    
    local key_perms=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || echo "unknown")
    if [[ "$key_perms" != "400" ]]; then
        log_warning "SSH key permissions are $key_perms, should be 400"
        chmod 400 "$SSH_KEY_PATH"
        log_success "SSH key permissions corrected"
    fi
    
    # Check AWS CLI and credentials
    if ! command -v "$AWS_CLI_PATH" &> /dev/null; then
        log_error "AWS CLI not found at: $AWS_CLI_PATH"
        return 1
    fi
    
    if ! $AWS_CLI_PATH sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or invalid"
        return 1
    fi
    
    # Check required commands
    for cmd in ssh ssh-keyscan docker; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            return 1
        fi
    done
    
    # Check log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_success "Production prerequisites validation passed"
    return 0
}

# Main execution function with production safeguards
main() {
    echo "=========================================="
    echo "🚨 Pet Adoption Auto Discovery"
    echo "🚨 PRODUCTION Environment Deployment"
    echo "🚨 Handle with extreme care!"
    echo "=========================================="
    
    log_message "INFO" "Starting PRODUCTION deployment automation..."
    log_message "INFO" "Log file: $LOG_FILE"
    log_message "INFO" "Backup directory: $BACKUP_DIR"
    
    # Production confirmation
    confirm_production_deployment
    
    # Validate prerequisites
    if ! validate_production_prerequisites; then
        log_error "Production prerequisites validation failed"
        exit 1
    fi
    
    # Create backup before proceeding
    create_backup
    
    # Execute deployment steps with enhanced error handling
    if fetch_instance_ips && \
       update_ansible_inventory && \
       wait_for_production_instances && \
       manage_production_containers; then
        
        log_success "🎉 PRODUCTION deployment automation completed successfully!"
        echo ""
        echo "=== PRODUCTION DEPLOYMENT SUMMARY ==="
        echo "• Environment: PRODUCTION"
        echo "• Inventory file: $INVENTORY_FILE"
        echo "• IPs file: $IPS_FILE"
        echo "• Log file: $LOG_FILE"
        echo "• Backup directory: $BACKUP_DIR"
        echo "• Container: $CONTAINER_NAME"
        echo "• Deployment time: $(date)"
        echo ""
        echo "🔍 Next steps:"
        echo "1. Monitor application logs"
        echo "2. Check application health endpoints"
        echo "3. Verify load balancer health checks"
        echo "4. Monitor system metrics"
        echo ""
        
        return 0
    else
        log_error "PRODUCTION deployment automation failed"
        log_error "Check backup at: $BACKUP_DIR"
        log_error "Check logs at: $LOG_FILE"
        return 1
    fi
}

# Enhanced error handling for production
cleanup() {
    log_warning "Script interrupted - cleaning up..."
    log_message "INFO" "Backup available at: $BACKUP_DIR"
    log_message "INFO" "Logs available at: $LOG_FILE"
}

trap 'cleanup; exit 1' INT TERM

# Execute main function
main "$@"

### End of Pet Adoption Auto Discovery Production Script ###