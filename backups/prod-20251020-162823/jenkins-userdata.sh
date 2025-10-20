#!/bin/bash
# Minimal Jenkins Installation for Fiifi Pet Adoption Auto Discovery Project

set -e

# Set hostname
hostnamectl set-hostname fiifi-jenkins

# Update and install Java
yum update -y
yum install -y java-17-openjdk wget git maven unzip

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins

# Start Jenkins
systemctl enable jenkins
systemctl start jenkins

# Install Docker
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Trivy
RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]' /etc/os-release)
cat > /etc/yum.repos.d/trivy.repo << EOF
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$RELEASE_VERSION/\$basearch/
gpgcheck=0
enabled=1
EOF
yum install -y trivy

# Install SSM Agent
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

echo "Jenkins installation completed"