#!/bin/bash

# Bastion Host Setup Script
# Pet Adoption Auto Discovery Project

# System update
apt-get update -y

# Setup SSH Key
mkdir -p /home/ubuntu/.ssh
echo "${private_key}" > /home/ubuntu/.ssh/id_rsa
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# Set hostname
hostnamectl set-hostname bastion

# Install New Relic
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && \
sudo NEW_RELIC_API_KEY="${nr_license_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_account_id}" \
     NEW_RELIC_REGION=EU \
     /usr/local/bin/newrelic install -y