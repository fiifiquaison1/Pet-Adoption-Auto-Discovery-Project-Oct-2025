#!/bin/bash

# Comprehensive Jenkins installation for Fiifi Pet Adoption Auto Discovery Project
# With all required tools and configurations

set -e
exec > >(tee /var/log/jenkins-userdata.log) 2>&1

echo "Starting Jenkins installation at $(date)"

# Default AWS region
export AWS_DEFAULT_REGION=eu-west-3

# Set hostname to fiifi-jenkins
echo "Setting hostname to fiifi-jenkins..."
hostnamectl set-hostname fiifi-jenkins
echo "127.0.0.1 fiifi-jenkins" >> /etc/hosts

# Update OS and install dependencies
echo "Updating system packages..."
dnf update -y

echo "Installing required dependencies..."
dnf install -y wget curl unzip git tar gzip

# Install Amazon SSM Agent
echo "Installing Amazon SSM Agent..."
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install Session Manager plugin
echo "Installing Session Manager plugin..."
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
dnf install -y ./session-manager-plugin.rpm
rm -f session-manager-plugin.rpm

# Install Java 11 (required for Jenkins)
echo "Installing Java 11..."
dnf install -y java-11-openjdk java-11-openjdk-devel

# Set JAVA_HOME
echo "Setting JAVA_HOME..."
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' | tee -a /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk

# Jenkins repository and key
echo "Adding Jenkins repository..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade system and install Java & Jenkins
echo "Installing Jenkins..."
dnf install -y jenkins

# Systemd configuration for Jenkins
echo "Configuring Jenkins systemd service..."
systemctl daemon-reload
systemctl enable jenkins

# Docker installation and configuration
echo "Installing Docker..."
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker
systemctl enable docker
systemctl start docker

# Add jenkins user to docker group
usermod -aG docker jenkins

# Trivy installation
echo "Installing Trivy..."
cat > /etc/yum.repos.d/trivy.repo << 'EOF'
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF
dnf install -y trivy

# AWS CLI installation
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Start Jenkins service
echo "Starting Jenkins service..."
systemctl start jenkins

# Wait and check status
echo "Waiting for Jenkins to start..."
sleep 30

# Check if Jenkins is running
if systemctl is-active --quiet jenkins; then
    echo "SUCCESS: Jenkins service is running"
    
    # Wait for Jenkins to be fully ready
    echo "Waiting for Jenkins to be fully ready..."
    timeout=300
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if curl -s http://localhost:8080/login > /dev/null 2>&1; then
            echo "Jenkins web interface is ready"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "Waiting... ($elapsed seconds)"
    done
    
    # Display initial admin password location
    echo "Jenkins initial admin password location: /var/lib/jenkins/secrets/initialAdminPassword"
    
    # Get initial admin password
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
        echo "Jenkins initial admin password: $INITIAL_PASSWORD"
        echo "$INITIAL_PASSWORD" | tee /opt/jenkins-initial-password.txt
        chmod 644 /opt/jenkins-initial-password.txt
    fi
    
else
    echo "ERROR: Jenkins service failed to start"
    systemctl status jenkins --no-pager
    journalctl -u jenkins --no-pager -n 20
fi

# Configure firewall for Jenkins (port 8080)
firewall-cmd --permanent --zone=public --add-port=8080/tcp || true
firewall-cmd --reload || true

# Create completion marker
echo "Jenkins installation completed successfully at $(date)" | tee /opt/jenkins-ready.txt

echo "Jenkins installation completed at $(date)"
echo "Hostname: $(hostname)"
echo "AWS CLI version: $(aws --version)"
echo "Docker version: $(docker --version)"
echo "Trivy version: $(trivy --version)"
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
sudo usermod -a -G docker jenkins

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo dnf install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform for infrastructure management
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf -y install terraform

# Install kubectl for Kubernetes management
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Node.js and npm for frontend builds
sudo dnf module install -y nodejs:18/common

# Install Python 3 and pip
sudo dnf install -y python3 python3-pip

# Install additional tools
sudo dnf install -y wget curl unzip vim htop

# Configure Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to start
sleep 30

# Create Jenkins workspace directory for Fiifi Pet Adoption project
sudo mkdir -p /var/lib/jenkins/workspace/fiifi-pet-adoption-auto-discovery
sudo chown jenkins:jenkins /var/lib/jenkins/workspace/fiifi-pet-adoption-auto-discovery

# Install Jenkins plugins via CLI (after Jenkins is fully started)
# Download Jenkins CLI
sudo wget -O /var/lib/jenkins/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar

# Create a script to install plugins after Jenkins is ready
cat << 'EOF' | sudo tee /tmp/install-jenkins-plugins.sh
#!/bin/bash
# Wait for Jenkins to be fully ready
while ! curl -s http://localhost:8080/login > /dev/null; do
    echo "Waiting for Jenkins to start..."
    sleep 10
done

# Get initial admin password
INITIAL_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

# Install essential plugins
JENKINS_URL="http://localhost:8080"
JENKINS_CLI="java -jar /var/lib/jenkins/jenkins-cli.jar -s $JENKINS_URL"

# List of plugins to install
PLUGINS=(
    "git"
    "github"
    "pipeline-stage-view"
    "docker-workflow"
    "aws-credentials"
    "terraform"
    "kubernetes"
    "nodejs"
    "python"
    "pipeline-utility-steps"
    "build-timeout"
    "credentials-binding"
    "timestamper"
    "ws-cleanup"
    "ant"
    "gradle"
    "workflow-aggregator"
    "github-branch-source"
    "pipeline-github-lib"
    "ssh-slaves"
    "matrix-auth"
    "pam-auth"
    "ldap"
    "email-ext"
    "mailer"
)

# Install plugins
for plugin in "${PLUGINS[@]}"; do
    echo "Installing plugin: $plugin"
    echo 'jenkins.model.Jenkins.instance.securityRealm.createAccount("admin", "'$INITIAL_PASSWORD'")' | $JENKINS_CLI groovy || true
done
EOF

chmod +x /tmp/install-jenkins-plugins.sh
sudo -u jenkins /tmp/install-jenkins-plugins.sh &

# Configure firewall for Jenkins (port 8080)
sudo firewall-cmd --permanent --zone=public --add-port=8080/tcp || true
sudo firewall-cmd --reload || true

# Create systemd service for Fiifi Pet Adoption project health check
cat << EOF | sudo tee /etc/systemd/system/fiifi-pet-adoption-health.service
[Unit]
Description=Fiifi Pet Adoption Auto Discovery Health Check
After=jenkins.service

[Service]
Type=simple
User=jenkins
ExecStart=/bin/bash -c 'while true; do curl -s http://localhost:8080 > /dev/null && echo "Jenkins is healthy" || echo "Jenkins is not responding"; sleep 60; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fiifi-pet-adoption-health.service
sudo systemctl start fiifi-pet-adoption-health.service

# Create Jenkins job configuration for Fiifi Pet Adoption project
sudo mkdir -p /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline
cat << 'EOF' | sudo tee /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline/config.xml
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

sudo chown jenkins:jenkins /var/lib/jenkins/jobs/fiifi-pet-adoption-pipeline/config.xml

# Set up log rotation for Jenkins
sudo tee /etc/logrotate.d/jenkins << EOF
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

# Create status file
echo "Jenkins installation completed at $(date)" | sudo tee /var/log/jenkins-install.log
echo "Initial admin password: $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)" | sudo tee -a /var/log/jenkins-install.log
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080" | sudo tee -a /var/log/jenkins-install.log

# Final restart to ensure all services are running
sudo systemctl restart jenkins

echo "Jenkins installation and configuration completed successfully!"
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Initial admin password can be found in: /var/lib/jenkins/secrets/initialAdminPassword"