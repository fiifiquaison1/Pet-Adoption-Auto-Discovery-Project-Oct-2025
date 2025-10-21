#!/bin/bash

# Pet Adoption Auto Discovery Project - Staging Ansible Deployment Script
# Author: Fiifi Quaison
# Description: Automated deployment and container management for staging environment

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
AWS_CLI_PATH='/usr/local/bin/aws'
INVENTORY_FILE='/etc/ansible/stage_hosts'
IPS_FILE='/etc/ansible/stage_ips.list'
ASG_NAME='fiifi-pet-adoption-stage-asg'
SSH_KEY_PATH='/home/ec2-user/.ssh/fiifi-pet-adoption-key.pem'
WAIT_TIME=30
ANSIBLE_USER='ec2-user'
CONTAINER_NAME='pet-adoption-app'
STARTUP_SCRIPT_PATH='/home/ec2-user/scripts/start-container.sh'
LOG_FILE="/var/log/ansible-stage-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] [$level]${NC} $message" | tee -a "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}✅ $message${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}❌ ERROR: $message${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  WARNING: $message${NC}" | tee -a "$LOG_FILE"
}

# Fetch instance IPs from Auto Scaling Group
fetch_instance_ips() {
    log_message "INFO" "Fetching instance IPs from ASG: $ASG_NAME"
    
    if ! command -v "$AWS_CLI_PATH" &> /dev/null; then
        log_error "AWS CLI not found at $AWS_CLI_PATH"
        return 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$IPS_FILE")"
    
    if $AWS_CLI_PATH ec2 describe-instances \
        --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
        --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress' \
        --output text > "$IPS_FILE"; then
        
        local ip_count=$(wc -l < "$IPS_FILE")
        log_success "Found $ip_count instance(s) in ASG"
        return 0
    else
        log_error "Failed to fetch instance IPs from ASG"
        return 1
    fi
}

# Update Ansible inventory file
update_ansible_inventory() {
    log_message "INFO" "Updating Ansible inventory file: $INVENTORY_FILE"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$INVENTORY_FILE")"
    
    # Check if IPs file exists and has content
    if [[ ! -f "$IPS_FILE" ]] || [[ ! -s "$IPS_FILE" ]]; then
        log_error "IPs file is empty or doesn't exist: $IPS_FILE"
        return 1
    fi
    
    # Create inventory header
    cat > "$INVENTORY_FILE" << EOF
# Pet Adoption Auto Discovery - Staging Environment Inventory
# Generated on: $(date)
[staging_webservers]
EOF
    
    # Add each instance to inventory and known_hosts
    while IFS= read -r instance_ip; do
        if [[ -n "$instance_ip" && "$instance_ip" != "None" ]]; then
            log_message "INFO" "Adding instance to inventory: $instance_ip"
            
            # Add to known_hosts to avoid SSH prompts
            if ssh-keyscan -H "$instance_ip" >> ~/.ssh/known_hosts 2>/dev/null; then
                log_success "Added $instance_ip to known_hosts"
            else
                log_warning "Failed to add $instance_ip to known_hosts"
            fi
            
            # Add to inventory
            echo "$instance_ip ansible_user=$ANSIBLE_USER ansible_ssh_private_key_file=$SSH_KEY_PATH" >> "$INVENTORY_FILE"
        fi
    done < "$IPS_FILE"
    
    log_success "Ansible inventory updated successfully"
    return 0
}

# Wait for instances to be ready
wait_for_instances() {
    log_message "INFO" "Waiting $WAIT_TIME seconds for instances to be ready..."
    sleep "$WAIT_TIME"
    log_success "Wait period completed"
}

# Check and manage Docker containers on instances
manage_docker_containers() {
    log_message "INFO" "Checking Docker containers on staging instances..."
    
    if [[ ! -f "$IPS_FILE" ]] || [[ ! -s "$IPS_FILE" ]]; then
        log_error "No instances found to check"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r instance_ip; do
        if [[ -n "$instance_ip" && "$instance_ip" != "None" ]]; then
            total_count=$((total_count + 1))
            log_message "INFO" "Checking container on instance: $instance_ip"
            
            # Check if container is running
            if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                "$ANSIBLE_USER@$instance_ip" \
                "docker ps --filter name=$CONTAINER_NAME --format '{{.Names}}' | grep -q $CONTAINER_NAME" 2>/dev/null; then
                
                log_success "Container '$CONTAINER_NAME' is running on $instance_ip"
                success_count=$((success_count + 1))
            else
                log_warning "Container '$CONTAINER_NAME' not running on $instance_ip"
                
                # Attempt to start the container
                log_message "INFO" "Starting container on $instance_ip..."
                if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
                    "$ANSIBLE_USER@$instance_ip" \
                    "bash $STARTUP_SCRIPT_PATH" 2>/dev/null; then
                    
                    log_success "Container startup script executed on $instance_ip"
                    success_count=$((success_count + 1))
                else
                    log_error "Failed to start container on $instance_ip"
                fi
            fi
        fi
    done < "$IPS_FILE"
    
    log_message "INFO" "Container check completed: $success_count/$total_count instances successful"
    return 0
}

# Validate prerequisites
validate_prerequisites() {
    log_message "INFO" "Validating prerequisites..."
    
    # Check SSH key exists
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH key not found: $SSH_KEY_PATH"
        return 1
    fi
    
    # Check AWS CLI
    if ! command -v "$AWS_CLI_PATH" &> /dev/null; then
        log_error "AWS CLI not found at: $AWS_CLI_PATH"
        return 1
    fi
    
    # Check SSH command
    if ! command -v ssh &> /dev/null; then
        log_error "SSH command not available"
        return 1
    fi
    
    log_success "Prerequisites validation passed"
    return 0
}

# Main execution function
main() {
    echo "=========================================="
    echo "Pet Adoption Auto Discovery"
    echo "Staging Environment Deployment"
    echo "=========================================="
    
    log_message "INFO" "Starting staging deployment automation..."
    log_message "INFO" "Log file: $LOG_FILE"
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi
    
    # Execute deployment steps
    if fetch_instance_ips && \
       update_ansible_inventory && \
       wait_for_instances && \
       manage_docker_containers; then
        
        log_success "🎉 Staging deployment automation completed successfully!"
        echo ""
        echo "Summary:"
        echo "• Inventory file: $INVENTORY_FILE"
        echo "• IPs file: $IPS_FILE"
        echo "• Log file: $LOG_FILE"
        echo "• Container: $CONTAINER_NAME"
        echo ""
        
        return 0
    else
        log_error "Staging deployment automation failed"
        return 1
    fi
}

# Error handling
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"

### End of Pet Adoption Auto Discovery Staging Script ###
