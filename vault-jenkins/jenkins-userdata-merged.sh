#!/bin/bash

# Comprehensive Jenkins installation for Fiifi Pet Adoption Auto Discovery Project
# Merged script combining optimized performance with full feature set
# Created: October 19, 2025
# Purpose: Single source of truth for Jenkins configuration

set -e
exec > >(tee /var/log/jenkins-userdata.log) 2>&1

echo "====================================================================="
echo "Starting Jenkins installation for Fiifi Pet Adoption Auto Discovery"
echo "Installation started at: $(date)"
echo "====================================================================="

# Default AWS region
export AWS_DEFAULT_REGION=eu-west-3

# Enhanced logging function
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

log_success() {
    echo "[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
handle_error() {
    log_error "Script failed on line $1"
    log_error "Last command: $BASH_COMMAND"
    exit 1
}
trap 'handle_error $LINENO' ERR

# Set hostname to fiifi-jenkins
log_info "Setting hostname to fiifi-jenkins..."
hostnamectl set-hostname fiifi-jenkins
echo "127.0.0.1 fiifi-jenkins" >> /etc/hosts
log_success "Hostname configured"

# Update OS and install dependencies
log_info "Updating system packages..."
dnf update -y

log_info "Installing required dependencies..."
dnf install -y wget curl unzip git tar gzip vim htop

# Choose Java version - Java 17 for better performance, fallback to Java 11
log_info "Installing Java..."
if dnf install -y java-17-openjdk java-17-openjdk-devel; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' | tee /etc/environment
    log_success "Java 17 installed successfully"
else
    log_info "Java 17 failed, falling back to Java 11..."
    dnf install -y java-11-openjdk java-11-openjdk-devel
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' | tee /etc/environment
    log_success "Java 11 installed successfully"
fi

# Install Amazon SSM Agent
log_info "Installing Amazon SSM Agent..."
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
log_success "SSM Agent installed and started"

# Install Session Manager plugin
log_info "Installing Session Manager plugin..."
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
dnf install -y ./session-manager-plugin.rpm
rm -f session-manager-plugin.rpm
log_success "Session Manager plugin installed"

# Jenkins repository and installation
log_info "Adding Jenkins repository..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

log_info "Installing Jenkins..."
dnf install -y jenkins
log_success "Jenkins package installed"

# Systemd configuration for Jenkins
log_info "Configuring Jenkins systemd service..."
systemctl daemon-reload
systemctl enable jenkins

# Docker installation and configuration
log_info "Installing Docker..."
if ! dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo; then
    log_info "Docker repository failed, trying alternative installation..."
    dnf install -y docker || {
        log_error "Docker installation failed"
        exit 1
    }
else
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Configure Docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins
log_success "Docker installed and configured"

# Trivy installation for security scanning
log_info "Installing Trivy..."
cat > /etc/yum.repos.d/trivy.repo << 'EOF'
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF
dnf install -y trivy
log_success "Trivy security scanner installed"

# AWS CLI installation with fallback
log_info "Installing AWS CLI..."
if dnf install -y awscli; then
    log_success "AWS CLI installed via package manager"
else
    log_info "Package manager failed, installing AWS CLI manually..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    log_success "AWS CLI installed manually"
fi

# Install Terraform for infrastructure management
log_info "Installing Terraform..."
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
dnf -y install terraform
log_success "Terraform installed"

# Install kubectl for Kubernetes management
log_info "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
log_success "kubectl installed"

# Install Node.js and npm for frontend builds
log_info "Installing Node.js..."
dnf module install -y nodejs:18/common
log_success "Node.js installed"

# Install Python 3 and pip
log_info "Installing Python..."
dnf install -y python3 python3-pip
log_success "Python installed"

# Start Jenkins service
log_info "Starting Jenkins service..."
systemctl start jenkins

# Wait and check status with improved feedback
log_info "Waiting for Jenkins to start..."
sleep 30

# Check if Jenkins is running
if systemctl is-active --quiet jenkins; then
    log_success "Jenkins service is running"
    
    # Wait for Jenkins to be fully ready with timeout
    log_info "Waiting for Jenkins web interface to be ready..."
    timeout=300
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if curl -s http://localhost:8080/login > /dev/null 2>&1; then
            log_success "Jenkins web interface is ready"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        log_info "Still waiting... ($elapsed seconds elapsed)"
    done
    
    if [ $elapsed -ge $timeout ]; then
        log_error "Jenkins web interface failed to start within $timeout seconds"
        systemctl status jenkins --no-pager
        journalctl -u jenkins --no-pager -n 20
        exit 1
    fi
    
    # Get initial admin password
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
        log_success "Jenkins initial admin password retrieved"
        echo "$INITIAL_PASSWORD" | tee /opt/jenkins-initial-password.txt
        chmod 644 /opt/jenkins-initial-password.txt
    else
        log_error "Initial admin password file not found"
    fi
    
else
    log_error "Jenkins service failed to start"
    systemctl status jenkins --no-pager
    journalctl -u jenkins --no-pager -n 20
    exit 1
fi

# Configure firewall for Jenkins (port 8080)
log_info "Configuring firewall..."
firewall-cmd --permanent --zone=public --add-port=8080/tcp || true
firewall-cmd --reload || true
log_success "Firewall configured for Jenkins"

# Create Jenkins workspace directory for Fiifi Pet Adoption project
log_info "Creating project workspace..."
mkdir -p /var/lib/jenkins/workspace/fiifi-pet-adoption-auto-discovery
chown jenkins:jenkins /var/lib/jenkins/workspace/fiifi-pet-adoption-auto-discovery
log_success "Project workspace created"

# Create Jenkins job configuration for Fiifi Pet Adoption project
log_info "Creating Jenkins pipeline configuration..."
mkdir -p /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline
cat << 'EOF' > /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline/config.xml
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@1316.vd2290d3341a_f">
  <actions/>
  <description>Fiifi Pet Adoption Auto Discovery Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.plugins.jira.JiraProjectProperty plugin="jira@3.7"/>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>30</daysToKeep>
        <numToKeep>10</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>ENVIRONMENT</name>
          <description>Target environment for deployment</description>
          <defaultValue>dev</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@3659.v582dc37621d8">
    <script>pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'eu-west-3'
        PROJECT_NAME = 'fiifi-pet-adoption-auto-discovery'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/fiifiquaison1/Pet-Adoption-Auto-Discovery-Project-Oct-2025.git'
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building Fiifi Pet Adoption Auto Discovery application...'
                // Add your build commands here
            }
        }
        
        stage('Security Scan') {
            steps {
                echo 'Running security scan with Trivy...'
                // Add Trivy scanning commands here
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests for Fiifi Pet Adoption Auto Discovery...'
                // Add your test commands here
            }
        }
        
        stage('Deploy') {
            steps {
                echo "Deploying to ${params.ENVIRONMENT} environment..."
                // Add your deployment commands here
            }
        }
    }
    
    post {
        always {
            echo 'Fiifi Pet Adoption Auto Discovery pipeline completed!'
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

chown jenkins:jenkins /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline/config.xml
log_success "Jenkins pipeline configuration created"

# Create systemd service for Fiifi Pet Adoption project health check
log_info "Creating health check service..."
cat << EOF > /etc/systemd/system/fiifi-pet-adoption-health.service
[Unit]
Description=Fiifi Pet Adoption Auto Discovery Health Check
After=jenkins.service

[Service]
Type=simple
User=jenkins
ExecStart=/bin/bash -c 'while true; do curl -s http://localhost:8080 > /dev/null && echo "[$(date)] Jenkins is healthy" || echo "[$(date)] Jenkins is not responding"; sleep 60; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable fiifi-pet-adoption-health.service
systemctl start fiifi-pet-adoption-health.service
log_success "Health check service configured"

# Set up log rotation for Jenkins
log_info "Configuring log rotation..."
tee /etc/logrotate.d/jenkins << EOF
/var/log/jenkins/jenkins.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 jenkins jenkins
    postrotate
        systemctl reload jenkins || true
    endscript
}
EOF
log_success "Log rotation configured"

# Create status script for monitoring
log_info "Creating status monitoring script..."
cat << 'EOF' > /opt/jenkins-status.sh
#!/bin/bash
echo "===== Jenkins Status Report ====="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""
echo "Service Status:"
systemctl is-active jenkins && echo "✓ Jenkins: Running" || echo "✗ Jenkins: Not Running"
systemctl is-active docker && echo "✓ Docker: Running" || echo "✗ Docker: Not Running"
systemctl is-active amazon-ssm-agent && echo "✓ SSM Agent: Running" || echo "✗ SSM Agent: Not Running"
echo ""
echo "Network Status:"
curl -s http://localhost:8080/login > /dev/null && echo "✓ Jenkins Web UI: Accessible" || echo "✗ Jenkins Web UI: Not Accessible"
echo ""
echo "Tool Versions:"
echo "Java: $(java -version 2>&1 | head -n1)"
echo "Docker: $(docker --version)"
echo "AWS CLI: $(aws --version)"
echo "Terraform: $(terraform version | head -n1)"
echo "kubectl: $(kubectl version --client --short 2>/dev/null)"
echo "Trivy: $(trivy --version | head -n1)"
echo ""
echo "Initial Admin Password Location: /var/lib/jenkins/secrets/initialAdminPassword"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Initial Password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
fi
echo ""
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Not available")
echo "Access Jenkins at: http://$PUBLIC_IP:8080"
echo "============================="
EOF

chmod +x /opt/jenkins-status.sh
log_success "Status monitoring script created"

# Create completion marker with detailed information
log_info "Creating completion markers..."
cat << EOF > /opt/jenkins-ready.txt
Jenkins installation completed successfully at $(date)

Server Information:
- Hostname: $(hostname)
- AWS Region: $AWS_DEFAULT_REGION
- Java Version: $(java -version 2>&1 | head -n1)

Installed Tools:
- Jenkins: $(systemctl is-active jenkins)
- Docker: $(docker --version)
- AWS CLI: $(aws --version)
- Terraform: $(terraform version | head -n1)
- kubectl: Available
- Trivy: $(trivy --version | head -n1)
- Node.js: $(node --version 2>/dev/null || echo "Not available")
- Python: $(python3 --version)

Access Information:
- Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost"):8080
- Initial Admin Password: $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not available")

Log Files:
- Installation Log: /var/log/jenkins-userdata.log
- Jenkins Log: /var/log/jenkins/jenkins.log

Status Script: /opt/jenkins-status.sh
EOF

echo "Jenkins installation completed successfully at $(date)" >> /var/log/jenkins-install.log

# Final restart to ensure all services are running
log_info "Performing final service restart..."
systemctl restart jenkins
sleep 10

# Final status check
if systemctl is-active --quiet jenkins && curl -s http://localhost:8080/login > /dev/null; then
    log_success "All services are running correctly"
else
    log_error "Some services may not be running correctly"
    /opt/jenkins-status.sh
fi

echo "====================================================================="
echo "Jenkins installation and configuration completed successfully!"
echo "Installation completed at: $(date)"
echo ""
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost"):8080"
echo "Initial admin password: $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Check /var/lib/jenkins/secrets/initialAdminPassword")"
echo ""
echo "Run '/opt/jenkins-status.sh' for detailed status information"
echo "====================================================================="