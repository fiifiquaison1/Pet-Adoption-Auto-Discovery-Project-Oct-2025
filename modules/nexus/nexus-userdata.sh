#!/bin/bash

# Nexus Repository Manager Setup Script
# Pet Adoption Auto Discovery Project - Nexus Server Configuration
# Author: Fiifi Quaison
# Date: October 22, 2025

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables
NEXUS_VERSION="3.80.0-06"
NEXUS_USER="nexus"
NEXUS_INSTALL_DIR="/opt/nexus"
NEXUS_DATA_DIR="/opt/sonatype-work"
DOWNLOAD_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"
LOG_FILE="/var/log/nexus-setup.log"

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
    log "$message"
}

# Error handling
error_exit() {
    print_status "$RED" "ERROR: $1"
    exit 1
}

# Start setup
print_status "$GREEN" "🚀 Starting Nexus Repository Manager Setup"
print_status "$BLUE" "📦 Version: $NEXUS_VERSION"

# 1. System Update and Java Installation
print_status "$BLUE" "📦 Updating system packages..."
sudo dnf update -y || error_exit "Failed to update system packages"

print_status "$BLUE" "☕ Installing Java 21..."
sudo dnf install -y java-21-openjdk java-21-openjdk-devel wget tar || error_exit "Failed to install Java"

# Verify Java installation
if java -version 2>&1 | grep -q "21"; then
    print_status "$GREEN" "✅ Java 21 installed successfully"
else
    error_exit "Java 21 installation verification failed"
fi

# 2. Install AWS SSM Agent
print_status "$BLUE" "🔧 Installing AWS SSM Agent..."
sudo dnf install -y https://s3.eu-west-3.amazonaws.com/amazon-ssm-eu-west-3/latest/linux_amd64/amazon-ssm-agent.rpm || \
    print_status "$YELLOW" "⚠️ SSM Agent installation failed, continuing..."

curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "/tmp/session-manager-plugin.rpm"
sudo dnf install -y /tmp/session-manager-plugin.rpm || \
    print_status "$YELLOW" "⚠️ Session Manager plugin installation failed, continuing..."

# 3. Create Nexus User
print_status "$BLUE" "👤 Creating nexus user..."
if id "$NEXUS_USER" &>/dev/null; then
    print_status "$YELLOW" "⚠️ User $NEXUS_USER already exists"
else
    sudo useradd -r -M -d "$NEXUS_INSTALL_DIR" -s /bin/false "$NEXUS_USER" || error_exit "Failed to create nexus user"
    print_status "$GREEN" "✅ User $NEXUS_USER created successfully"
fi

# 4. Download and Extract Nexus
print_status "$BLUE" "📥 Downloading Nexus $NEXUS_VERSION..."
cd /tmp
sudo wget -O nexus.tar.gz "$DOWNLOAD_URL" || error_exit "Failed to download Nexus"

print_status "$BLUE" "📦 Extracting Nexus..."
sudo tar -xzf nexus.tar.gz || error_exit "Failed to extract Nexus"

# 5. Install Nexus
print_status "$BLUE" "📂 Installing Nexus to $NEXUS_INSTALL_DIR..."
sudo rm -rf "$NEXUS_INSTALL_DIR" "$NEXUS_DATA_DIR" 2>/dev/null || true
sudo mv "nexus-${NEXUS_VERSION}" "$NEXUS_INSTALL_DIR" || error_exit "Failed to move Nexus installation"
sudo mv sonatype-work "$NEXUS_DATA_DIR" || error_exit "Failed to move Nexus data directory"

# 6. Set Permissions
print_status "$BLUE" "🔒 Setting permissions..."
sudo chmod +x /opt
sudo chmod +x "$NEXUS_INSTALL_DIR/bin/nexus"
sudo chmod -R u+rx "$NEXUS_INSTALL_DIR/bin"
sudo chown -R "$NEXUS_USER:$NEXUS_USER" "$NEXUS_INSTALL_DIR"
sudo chown -R "$NEXUS_USER:$NEXUS_USER" "$NEXUS_DATA_DIR"

# 7. Configure Nexus User
print_status "$BLUE" "⚙️ Configuring Nexus to run as $NEXUS_USER..."
echo "run_as_user=$NEXUS_USER" | sudo tee "$NEXUS_INSTALL_DIR/bin/nexus.rc" > /dev/null

# 8. Create Systemd Service
print_status "$BLUE" "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/nexus.service > /dev/null <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=$NEXUS_INSTALL_DIR/bin/nexus start
ExecStop=$NEXUS_INSTALL_DIR/bin/nexus stop
User=$NEXUS_USER
Restart=on-failure
RestartSec=10
Environment=HOME=$NEXUS_INSTALL_DIR
WorkingDirectory=$NEXUS_INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

# 9. Handle SELinux
print_status "$BLUE" "🔒 Configuring SELinux..."
SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Disabled")

if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
    print_status "$YELLOW" "⚠️ Disabling SELinux for Nexus compatibility..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    print_status "$YELLOW" "⚠️ SELinux disabled - reboot required for permanent effect"
else
    print_status "$GREEN" "✅ SELinux is in $SELINUX_STATUS mode"
fi

# 10. Configure Firewall
print_status "$BLUE" "🔥 Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=8081/tcp || print_status "$YELLOW" "⚠️ Failed to open port 8081"
    sudo firewall-cmd --permanent --add-port=8085/tcp || print_status "$YELLOW" "⚠️ Failed to open port 8085"
    sudo firewall-cmd --reload || print_status "$YELLOW" "⚠️ Failed to reload firewall"
    print_status "$GREEN" "✅ Firewall configured for ports 8081, 8085"
else
    print_status "$YELLOW" "⚠️ Firewalld not running, skipping firewall configuration"
fi

# 11. Start Nexus Service
print_status "$BLUE" "🚀 Starting Nexus service..."
sudo systemctl daemon-reload
sudo systemctl enable nexus || error_exit "Failed to enable Nexus service"
sudo systemctl start nexus || error_exit "Failed to start Nexus service"

# 12. Wait for Nexus to Start
print_status "$BLUE" "⏳ Waiting for Nexus to start..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet nexus; then
        print_status "$GREEN" "✅ Nexus service is running"
        break
    fi
    if [ $i -eq 30 ]; then
        error_exit "Nexus failed to start within 5 minutes"
    fi
    sleep 10
done

# 13. Display Setup Summary
print_status "$GREEN" "🎉 Nexus Repository Manager Setup Complete!"
echo "=================================="
echo ""
print_status "$BLUE" "📋 Setup Summary:"
echo "• Nexus Version: $NEXUS_VERSION"
echo "• Installation Directory: $NEXUS_INSTALL_DIR"
echo "• Data Directory: $NEXUS_DATA_DIR"
echo "• Service User: $NEXUS_USER"
echo "• Web UI: http://$(curl -s ifconfig.me):8081"
echo "• Docker Registry: $(curl -s ifconfig.me):8085"
echo ""
print_status "$BLUE" "📝 Important Notes:"
echo "• Nexus is starting up and may take a few minutes to be fully accessible"
echo "• Default admin password: sudo cat $NEXUS_DATA_DIR/nexus3/admin.password"
echo "• Check service status: sudo systemctl status nexus"
echo "• View logs: sudo journalctl -u nexus -f"
echo ""
print_status "$YELLOW" "🔒 Security Reminder:"
echo "• Change default admin password on first login"
echo "• Configure authentication and authorization"
echo "• Review security settings in Nexus web interface"

# Clean up
rm -f /tmp/nexus.tar.gz /tmp/session-manager-plugin.rpm

print_status "$GREEN" "✅ Setup completed successfully!"