#!/bin/bash

# Pet Adoption Auto Discovery Project - Ansible Server Setup Script
# This script configures the Ansible server for deployment automation

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration variables from Terraform
NEXUS_SERVER_IP="${nexus_server_ip}"
NEW_RELIC_LICENSE_KEY="${new_relic_license_key}"
NEW_RELIC_ACCOUNT_ID="${new_relic_account_id}"
S3_BUCKET_NAME="${s3_bucket_name}"

LOG_FILE="/var/log/ansible-setup.log"

print_status() {
    local color="$1"
    local message="$2"
    echo -e "$${color}$message$${NC}" | tee -a "$LOG_FILE"
}

# Set hostname
print_status "$BLUE" "Setting hostname..."
hostnamectl set-hostname fiifi-ansible-server

# Update system
print_status "$BLUE" "Updating system packages..."
yum update -y

# Install EPEL repository
print_status "$BLUE" "Installing EPEL repository..."
yum install -y epel-release

# Install required packages
print_status "$BLUE" "Installing required packages..."
yum install -y \
    ansible \
    git \
    python3 \
    python3-pip \
    curl \
    wget \
    unzip \
    docker \
    awscli

# Install Docker Ansible collection
print_status "$BLUE" "Installing Ansible Docker collection..."
ansible-galaxy collection install community.docker

# Configure Docker
print_status "$BLUE" "Configuring Docker..."
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Create Ansible directories
print_status "$BLUE" "Creating Ansible directories..."
mkdir -p /etc/ansible
mkdir -p /home/ec2-user/ansible-playbooks
mkdir -p /home/ec2-user/scripts

# Configure Ansible
print_status "$BLUE" "Configuring Ansible..."
cat > /etc/ansible/ansible.cfg << EOF
[defaults]
host_key_checking = False
inventory = /etc/ansible/hosts
remote_user = ec2-user
private_key_file = /home/ec2-user/.ssh/fiifi-pet-adoption-key.pem
timeout = 30
gathering = smart
fact_caching = memory

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
EOF

# Create Ansible variables file
print_status "$BLUE" "Creating Ansible variables file..."
cat > /etc/ansible/ansible_vars_file.yml << EOF
# Pet Adoption Auto Discovery - Ansible Variables
nexus_server_ip: "$NEXUS_SERVER_IP"
nexus_username: "admin"
nexus_password: "admin123"
new_relic_license_key: "$NEW_RELIC_LICENSE_KEY"
new_relic_account_id: "$NEW_RELIC_ACCOUNT_ID"
s3_bucket_name: "$S3_BUCKET_NAME"
app_version: "latest"
spring_profile: "prod"
target_environment: "production_webservers"
EOF

# Download playbooks and scripts from S3
print_status "$BLUE" "Downloading Ansible playbooks and scripts from S3..."
aws s3 sync s3://$S3_BUCKET_NAME/ansible-scripts/ /home/ec2-user/ansible-playbooks/ || print_status "$YELLOW" "S3 sync failed - scripts may not be available yet"

# Set proper ownership
chown -R ec2-user:ec2-user /home/ec2-user/ansible-playbooks
chown -R ec2-user:ec2-user /home/ec2-user/scripts

# Create sample inventory files
print_status "$BLUE" "Creating sample inventory files..."
cat > /etc/ansible/staging_hosts << EOF
# Staging Environment Inventory
[staging_webservers]
# Instances will be dynamically added by stage-bashscript.sh

[staging_webservers:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=/home/ec2-user/.ssh/fiifi-pet-adoption-key.pem
EOF

cat > /etc/ansible/production_hosts << EOF
# Production Environment Inventory  
[production_webservers]
# Instances will be dynamically added by prod-bashscript.sh

[production_webservers:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=/home/ec2-user/.ssh/fiifi-pet-adoption-key.pem
EOF

# Install New Relic agent (if license key provided)
if [[ -n "$NEW_RELIC_LICENSE_KEY" && "$NEW_RELIC_LICENSE_KEY" != "" ]]; then
    print_status "$BLUE" "Installing New Relic infrastructure agent..."
    curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
    yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
    yum install -y newrelic-infra
    
    # Configure New Relic
    cat > /etc/newrelic-infra.yml << EOF
license_key: $NEW_RELIC_LICENSE_KEY
display_name: fiifi-ansible-server
EOF
    
    systemctl enable newrelic-infra
    systemctl start newrelic-infra
    print_status "$GREEN" "New Relic agent configured"
fi

# Create deployment status script
print_status "$BLUE" "Creating deployment status script..."
cat > /home/ec2-user/ansible-status.sh << 'EOF'
#!/bin/bash
echo "=== Pet Adoption Ansible Server Status ==="
echo "Hostname: $(hostname)"
echo "Ansible Version: $(ansible --version | head -1)"
echo "Docker Status: $(systemctl is-active docker)"
echo "Available Playbooks:"
ls -la /home/ec2-user/ansible-playbooks/ 2>/dev/null || echo "No playbooks found"
echo "Inventory Files:"
ls -la /etc/ansible/*_hosts 2>/dev/null || echo "No inventory files found"
echo "======================================="
EOF

chmod +x /home/ec2-user/ansible-status.sh
chown ec2-user:ec2-user /home/ec2-user/ansible-status.sh

# Install SSM Agent
print_status "$BLUE" "Installing SSM Agent..."
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

print_status "$GREEN" "✅ Ansible server setup completed successfully!"
print_status "$BLUE" "Server Details:"
print_status "$BLUE" "• Hostname: fiifi-ansible-server"
print_status "$BLUE" "• Ansible Config: /etc/ansible/ansible.cfg"
print_status "$BLUE" "• Variables File: /etc/ansible/ansible_vars_file.yml"
print_status "$BLUE" "• Playbooks Directory: /home/ec2-user/ansible-playbooks/"
print_status "$BLUE" "• Status Script: /home/ec2-user/ansible-status.sh"
print_status "$BLUE" "• Log File: $LOG_FILE"

print_status "$GREEN" "🚀 Ansible server is ready for Pet Adoption Auto Discovery deployments!"