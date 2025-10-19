#!/bin/bash
# Optimized Vault installation for faster deployment
set -e

VAULT_VERSION="1.18.3"

# Install minimal dependencies
apt update -y
apt install -y unzip wget

# Download and install Vault
wget https://releases.hashicorp.com/vault/"${VAULT_VERSION}"/vault_"${VAULT_VERSION}"_linux_amd64.zip
unzip vault_"${VAULT_VERSION}"_linux_amd64.zip
mv vault /usr/local/bin/
chmod 755 /usr/local/bin/vault

# Create Vault user and directories
useradd --system --home /etc/vault.d --shell /bin/false vault
mkdir -p /etc/vault.d /var/lib/vault
chown -R vault:vault /etc/vault.d /var/lib/vault

# Create optimized Vault configuration
cat > /etc/vault.d/vault.hcl << EOF
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
EOF

chown vault:vault /etc/vault.d/vault.hcl
chmod 640 /etc/vault.d/vault.hcl

# Create systemd service
cat > /etc/systemd/system/vault.service << 'EOF'
[Unit]
Description=HashiCorp Vault
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Start Vault service
systemctl daemon-reload
systemctl enable vault
systemctl start vault

# Set hostname
hostnamectl set-hostname fiifi-vault

# Export Vault address for future use
echo 'export VAULT_ADDR="http://localhost:8200"' >> /etc/profile

echo "Optimized Vault installation completed at $(date)"