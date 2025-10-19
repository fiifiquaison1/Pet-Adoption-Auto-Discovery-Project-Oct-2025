#!/bin/bash
# Optimized Jenkins installation for faster deployment
set -e
exec > >(tee /var/log/jenkins-userdata.log) 2>&1

echo "Starting optimized Jenkins installation at $(date)"

# Set hostname
hostnamectl set-hostname fiifi-jenkins

# Update and install minimal dependencies
dnf update -y
dnf install -y java-17-openjdk java-17-openjdk-devel wget curl

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' > /etc/environment

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Start Jenkins service immediately
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Install AWS SSM Agent
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install only essential tools
dnf install -y docker-ce || dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins

# Install AWS CLI (minimal version)
dnf install -y awscli || curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install

# Configure firewall
firewall-cmd --permanent --zone=public --add-port=8080/tcp || true
firewall-cmd --reload || true

# Create completion marker
echo "Optimized Jenkins installation completed at $(date)" | tee /opt/jenkins-ready.txt
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"