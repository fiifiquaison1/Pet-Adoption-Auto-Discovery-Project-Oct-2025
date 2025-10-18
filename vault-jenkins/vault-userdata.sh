#!/bin/bash

# Vault User Data Script for Fiifi Pet Adoption Auto Discovery Project
# This script installs and configures HashiCorp Vault on an Ubuntu instance

set -e  # Exit on any error

# Update system packages
sudo apt update -y
sudo apt upgrade -y

# Install required packages
sudo apt install -y wget curl unzip jq

# Create vault user
sudo useradd --system --home /etc/vault.d --shell /bin/false vault

# Download and install Vault
VAULT_VERSION="1.15.2"
cd /tmp
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
sudo chmod +x /usr/local/bin/vault

# Verify installation
vault --version

# Create Vault directories
sudo mkdir -p /etc/vault.d
sudo mkdir -p /opt/vault/data
sudo mkdir -p /opt/vault/logs

# Create Vault configuration
cat << 'EOF' | sudo tee /etc/vault.d/vault.hcl
# Fiifi Pet Adoption Auto Discovery Project - Vault Configuration

ui = true
disable_mlock = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"

# Plugin directory
plugin_directory = "/opt/vault/plugins"

# Log configuration
log_level = "INFO"
log_file = "/opt/vault/logs/vault.log"

# Telemetry
telemetry {
  disable_hostname = true
  prometheus_retention_time = "12h"
}

# Default lease TTL and max lease TTL
default_lease_ttl = "768h"
max_lease_ttl = "8760h"

# Fiifi Pet Adoption Project specific configuration
cluster_name = "fiifi-pet-adoption-vault"
EOF

# Set proper ownership and permissions
sudo chown -R vault:vault /etc/vault.d /opt/vault
sudo chmod 640 /etc/vault.d/vault.hcl

# Create Vault systemd service
cat << 'EOF' | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault - Fiifi Pet Adoption Auto Discovery
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
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
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Vault service
sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault

# Wait for Vault to start
sleep 10

# Set Vault environment variables
echo 'export VAULT_ADDR="http://127.0.0.1:8200"' | sudo tee -a /etc/environment
echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> ~/.bashrc
export VAULT_ADDR="http://127.0.0.1:8200"

# Configure firewall for Vault (port 8200)
sudo ufw allow 8200/tcp || true
sudo ufw --force enable || true

# Wait a bit more for Vault to be fully ready
sleep 15

# Initialize Vault (only if not already initialized)
if ! vault status | grep -q "Initialized.*true"; then
    echo "Initializing Vault..."
    vault operator init -key-shares=5 -key-threshold=3 -format=json > /tmp/vault-init.json
    
    # Extract keys and root token
    VAULT_UNSEAL_KEY_1=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[0]')
    VAULT_UNSEAL_KEY_2=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[1]')
    VAULT_UNSEAL_KEY_3=$(cat /tmp/vault-init.json | jq -r '.unseal_keys_b64[2]')
    VAULT_ROOT_TOKEN=$(cat /tmp/vault-init.json | jq -r '.root_token')
    
    # Store keys securely
    sudo mkdir -p /opt/vault/keys
    echo "$VAULT_UNSEAL_KEY_1" | sudo tee /opt/vault/keys/unseal_key_1
    echo "$VAULT_UNSEAL_KEY_2" | sudo tee /opt/vault/keys/unseal_key_2
    echo "$VAULT_UNSEAL_KEY_3" | sudo tee /opt/vault/keys/unseal_key_3
    echo "$VAULT_ROOT_TOKEN" | sudo tee /opt/vault/keys/root_token
    
    # Set proper permissions
    sudo chmod 600 /opt/vault/keys/*
    sudo chown vault:vault /opt/vault/keys/*
    
    # Unseal Vault
    vault operator unseal $VAULT_UNSEAL_KEY_1
    vault operator unseal $VAULT_UNSEAL_KEY_2
    vault operator unseal $VAULT_UNSEAL_KEY_3
    
    # Authenticate with root token
    vault auth $VAULT_ROOT_TOKEN
    
    # Enable audit logging
    vault audit enable file file_path=/opt/vault/logs/audit.log
    
    # Enable KV secrets engine for Fiifi Pet Adoption project
    vault secrets enable -path=fiifi-pet-adoption kv-v2
    
    # Enable AppRole auth method for Jenkins integration
    vault auth enable approle
    
    # Create a policy for Fiifi Pet Adoption project
    cat << 'POLICY_EOF' | vault policy write fiifi-pet-adoption-policy -
# Fiifi Pet Adoption Auto Discovery Project Policy
path "fiifi-pet-adoption/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "fiifi-pet-adoption/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
POLICY_EOF
    
    # Create AppRole for Jenkins
    vault write auth/approle/role/fiifi-jenkins-role \
        token_policies="fiifi-pet-adoption-policy" \
        token_ttl=1h \
        token_max_ttl=4h \
        bind_secret_id=true
    
    # Get role-id and secret-id for Jenkins
    ROLE_ID=$(vault read -field=role_id auth/approle/role/fiifi-jenkins-role/role-id)
    SECRET_ID=$(vault write -field=secret_id auth/approle/role/fiifi-jenkins-role/secret-id)
    
    # Store Jenkins credentials
    echo "$ROLE_ID" | sudo tee /opt/vault/keys/jenkins_role_id
    echo "$SECRET_ID" | sudo tee /opt/vault/keys/jenkins_secret_id
    sudo chmod 600 /opt/vault/keys/jenkins_*
    sudo chown vault:vault /opt/vault/keys/jenkins_*
    
    # Create some sample secrets for Fiifi Pet Adoption project
    vault kv put fiifi-pet-adoption/database \
        host="fiifi-pet-adoption-db.eu-west-3.rds.amazonaws.com" \
        username="fiifipetadmin" \
        password="generated-secure-password" \
        database="fiifi_pet_adoption_db"
    
    vault kv put fiifi-pet-adoption/api-keys \
        openai_api_key="sk-your-openai-api-key" \
        aws_access_key="AKIA..." \
        aws_secret_key="your-secret-key" \
        google_maps_key="your-google-maps-key"
    
    vault kv put fiifi-pet-adoption/application \
        environment="production" \
        debug_mode="false" \
        log_level="INFO" \
        max_connections="100"
    
    echo "Vault initialization completed successfully!"
else
    echo "Vault is already initialized"
fi

# Create auto-unseal script for restarts
cat << 'EOF' | sudo tee /opt/vault/auto-unseal.sh
#!/bin/bash
export VAULT_ADDR="http://127.0.0.1:8200"

# Check if Vault is sealed
if vault status | grep -q "Sealed.*true"; then
    echo "Vault is sealed, attempting to unseal..."
    
    # Read unseal keys
    KEY1=$(sudo cat /opt/vault/keys/unseal_key_1)
    KEY2=$(sudo cat /opt/vault/keys/unseal_key_2)
    KEY3=$(sudo cat /opt/vault/keys/unseal_key_3)
    
    # Unseal Vault
    vault operator unseal $KEY1
    vault operator unseal $KEY2
    vault operator unseal $KEY3
    
    echo "Vault unsealed successfully"
else
    echo "Vault is already unsealed"
fi
EOF

sudo chmod +x /opt/vault/auto-unseal.sh
sudo chown vault:vault /opt/vault/auto-unseal.sh

# Create systemd service for auto-unseal
cat << 'EOF' | sudo tee /etc/systemd/system/vault-auto-unseal.service
[Unit]
Description=Vault Auto Unseal - Fiifi Pet Adoption Project
After=vault.service
Requires=vault.service

[Service]
Type=oneshot
User=vault
Group=vault
ExecStart=/opt/vault/auto-unseal.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vault-auto-unseal.service

# Create health check script
cat << 'EOF' | sudo tee /opt/vault/health-check.sh
#!/bin/bash
export VAULT_ADDR="http://127.0.0.1:8200"

# Check Vault health
if curl -s http://127.0.0.1:8200/v1/sys/health | jq -r '.sealed' | grep -q false; then
    echo "$(date): Vault is healthy and unsealed"
    exit 0
else
    echo "$(date): Vault is not healthy or sealed"
    # Attempt to auto-unseal
    /opt/vault/auto-unseal.sh
    exit 1
fi
EOF

sudo chmod +x /opt/vault/health-check.sh
sudo chown vault:vault /opt/vault/health-check.sh

# Add cron job for health checks
echo "*/5 * * * * vault /opt/vault/health-check.sh >> /opt/vault/logs/health-check.log 2>&1" | sudo crontab -u vault -

# Create backup script
cat << 'EOF' | sudo tee /opt/vault/backup.sh
#!/bin/bash
export VAULT_ADDR="http://127.0.0.1:8200"
BACKUP_DIR="/opt/vault/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
sudo -u vault mkdir -p $BACKUP_DIR

# Backup Vault data
sudo -u vault tar -czf $BACKUP_DIR/vault_backup_$DATE.tar.gz -C /opt/vault data/

# Keep only last 7 days of backups
sudo -u vault find $BACKUP_DIR -name "vault_backup_*.tar.gz" -type f -mtime +7 -delete

echo "$(date): Vault backup completed: vault_backup_$DATE.tar.gz"
EOF

sudo chmod +x /opt/vault/backup.sh
sudo chown vault:vault /opt/vault/backup.sh

# Add daily backup cron job
echo "0 2 * * * vault /opt/vault/backup.sh >> /opt/vault/logs/backup.log 2>&1" | sudo crontab -u vault -

# Set up log rotation
sudo tee /etc/logrotate.d/vault << EOF
/opt/vault/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 vault vault
    postrotate
        systemctl reload vault || true
    endscript
}
EOF

# Create status file
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Vault installation completed at $(date)" | sudo tee /var/log/vault-install.log
echo "Vault URL: http://$PUBLIC_IP:8200" | sudo tee -a /var/log/vault-install.log
echo "Vault UI: http://$PUBLIC_IP:8200/ui" | sudo tee -a /var/log/vault-install.log

if [ -f /opt/vault/keys/root_token ]; then
    echo "Root token: $(sudo cat /opt/vault/keys/root_token)" | sudo tee -a /var/log/vault-install.log
    echo "Jenkins Role ID: $(sudo cat /opt/vault/keys/jenkins_role_id)" | sudo tee -a /var/log/vault-install.log
    echo "Jenkins Secret ID: $(sudo cat /opt/vault/keys/jenkins_secret_id)" | sudo tee -a /var/log/vault-install.log
fi

echo "Vault installation and configuration completed successfully!"
echo "Access Vault UI at: http://$PUBLIC_IP:8200/ui"
echo "Configuration details saved in: /var/log/vault-install.log"