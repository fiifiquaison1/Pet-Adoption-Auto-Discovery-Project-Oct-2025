#!/bin/bash
# Fiifi Pet Adoption Auto Discovery Project - Vault User Data Script (Merged)
# This script installs and configures HashiCorp Vault with AWS KMS auto-unsealing
# and initializes secrets for the pet adoption application

set -e  # Exit on any error

# Configuration
VAULT_VERSION="1.18.3"
LOG_FILE="/var/log/vault-setup.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output with timestamps
log_status() {
    echo -e "$${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]$${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "$${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]$${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "$${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING]$${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "$${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]$${NC} $1" | tee -a "$LOG_FILE"
}

# Function to update system
update_system() {
    log_status "Updating system packages..."
    apt update -y
    apt upgrade -y
    log_success "System updated successfully"
}

# Function to install dependencies
install_dependencies() {
    log_status "Installing required dependencies..."
    apt install -y unzip wget jq curl
    log_success "Dependencies installed successfully"
}

# Function to download and install Vault
install_vault() {
    log_status "Downloading Vault version $VAULT_VERSION..."
    
    # Download Vault binary
    wget -q https://releases.hashicorp.com/vault/"$${VAULT_VERSION}"/vault_"$${VAULT_VERSION}"_linux_amd64.zip
    
    # Unzip and install
    unzip -q vault_"$${VAULT_VERSION}"_linux_amd64.zip
    mv vault /usr/local/bin/
    
    # Set permissions
    chown root:root /usr/local/bin/vault
    chmod 755 /usr/local/bin/vault
    
    # Cleanup
    rm -f vault_"$${VAULT_VERSION}"_linux_amd64.zip
    
    log_success "Vault binary installed successfully"
}

# Function to create Vault user and directories
setup_vault_user() {
    log_status "Setting up Vault user and directories..."
    
    # Create Vault user
    useradd --system --home /etc/vault.d --shell /bin/false vault
    
    # Create directories
    mkdir -p /etc/vault.d /var/lib/vault /var/log/vault
    
    # Set ownership
    chown -R vault:vault /etc/vault.d /var/lib/vault /var/log/vault
    
    log_success "Vault user and directories created"
}

# Function to create Vault configuration
create_vault_config() {
    log_status "Creating Vault configuration..."
    
    cat > /etc/vault.d/vault.hcl << EOF
# Fiifi Pet Adoption Auto Discovery Project - Vault Configuration
storage "file" {
    path = "/var/lib/vault"
}

listener "tcp" {
    address     = "0.0.0.0:8200"
    tls_disable = 1
}

seal "awskms" {
    region = "${region}"
    kms_key_id = "${key}"
}

ui = true
disable_mlock = true
cluster_name = "fiifi-pet-adoption-vault"
log_level = "INFO"
log_file = "/var/log/vault/vault.log"
log_rotate_duration = "24h"
log_rotate_max_files = 7
EOF
    
    # Set permissions
    chown vault:vault /etc/vault.d/vault.hcl
    chmod 640 /etc/vault.d/vault.hcl
    
    log_success "Vault configuration created"
}

# Function to create systemd service
create_systemd_service() {
    log_status "Creating systemd service for Vault..."
    
    cat > /etc/systemd/system/vault.service << 'EOF'
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitInterval=60
StartLimitBurst=3

[Service]
Type=notify
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Systemd service created"
}

# Function to start Vault service
start_vault_service() {
    log_status "Starting Vault service..."
    
    # Reload systemd and start service
    systemctl daemon-reload
    systemctl enable vault
    systemctl start vault
    
    # Wait for Vault to start
    sleep 10
    
    # Check if Vault is running
    if systemctl is-active --quiet vault; then
        log_success "Vault service started successfully"
    else
        log_error "Failed to start Vault service"
        return 1
    fi
}

# Function to setup environment variables
setup_environment() {
    log_status "Setting up environment variables..."
    
    # Set Vault address in profile
    cat > /etc/profile.d/vault.sh << 'EOF'
export VAULT_ADDR='http://localhost:8200'
export VAULT_SKIP_VERIFY=true
EOF
    
    # Export for current session
    export VAULT_ADDR='http://localhost:8200'
    export VAULT_SKIP_VERIFY=true
    
    log_success "Environment variables configured"
}

# Function to initialize Vault and setup secrets
initialize_vault() {
    log_status "Initializing Vault and setting up secrets..."
    
    # Wait for Vault to be ready
    sleep 20
    
    # Initialize Vault
    vault operator init > /home/ubuntu/vault_init.log 2>&1 || {
        log_error "Failed to initialize Vault"
        return 1
    }
    
    # Extract root token
    grep -o 'hvs\.[A-Za-z0-9]\{24\}' /home/ubuntu/vault_init.log > /home/ubuntu/token.txt
    TOKEN=$(cat /home/ubuntu/token.txt)
    
    # Login to Vault
    vault login "$TOKEN" > /dev/null 2>&1 || {
        log_error "Failed to login to Vault"
        return 1
    }
    
    # Enable KV secrets engine
    vault secrets enable -path=secret/ kv || {
        log_warning "KV secrets engine may already be enabled"
    }
    
    # Store application secrets
    vault kv put secret/database username=petclinic password=petclinic || {
        log_error "Failed to store database secrets"
        return 1
    }
    
    vault kv put secret/app \
        name="Fiifi Pet Adoption Auto Discovery" \
        environment="production" \
        version="1.0.0" || {
        log_error "Failed to store application secrets"
        return 1
    }
    
    # Set proper file permissions
    chown ubuntu:ubuntu /home/ubuntu/vault_init.log /home/ubuntu/token.txt
    chmod 600 /home/ubuntu/vault_init.log /home/ubuntu/token.txt
    
    log_success "Vault initialized and secrets configured"
}

# Function to set hostname
set_hostname() {
    log_status "Setting hostname..."
    hostnamectl set-hostname fiifi-pet-adoption-vault
    log_success "Hostname set to fiifi-pet-adoption-vault"
}

# Function to create status script
create_status_script() {
    log_status "Creating Vault status script..."
    
    cat > /home/ubuntu/vault-status.sh << 'EOF'
#!/bin/bash
echo "=== Fiifi Pet Adoption Vault Status ==="
echo "Hostname: $(hostname)"
echo "Vault Version: $(vault version)"
echo "Vault Status: $(systemctl is-active vault)"
echo "Vault Address: $VAULT_ADDR"
echo "======================================="
EOF
    
    chmod +x /home/ubuntu/vault-status.sh
    chown ubuntu:ubuntu /home/ubuntu/vault-status.sh
    
    log_success "Status script created at /home/ubuntu/vault-status.sh"
}

# Main execution function
main() {
    log_status "Starting Fiifi Pet Adoption Auto Discovery Vault setup..."
    log_status "=========================================================="
    
    update_system
    install_dependencies
    install_vault
    setup_vault_user
    create_vault_config
    create_systemd_service
    setup_environment
    start_vault_service
    initialize_vault
    set_hostname
    create_status_script
    
    log_status "=========================================================="
    log_success "Vault setup completed successfully!"
    log_status "Vault Address: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8200"
    log_status "Root token saved to: /home/ubuntu/token.txt"
    log_status "Initialization log: /home/ubuntu/vault_init.log"
    log_status "Status script: /home/ubuntu/vault-status.sh"
    log_warning "Secure the root token and initialization output!"
}

# Execute main function
main "$@"