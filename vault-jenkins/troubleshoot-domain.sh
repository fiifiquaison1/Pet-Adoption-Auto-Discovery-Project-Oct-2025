#!/bin/bash
# Domain Troubleshooting Script for Fiifi Pet Adoption Auto Discovery Project
# This script helps diagnose domain and DNS issues

set -e

DOMAIN="fiifiquaison.space"
JENKINS_SUBDOMAIN="jenkins.${DOMAIN}"
VAULT_SUBDOMAIN="vault.${DOMAIN}"

echo "================================================="
echo "Domain Troubleshooting for ${DOMAIN}"
echo "================================================="

# Check if terraform is deployed
echo "1. Checking Terraform deployment status..."
if terraform show | grep -q "aws_route53_zone"; then
    echo "✅ Infrastructure is deployed"
    
    # Get Route53 name servers
    echo ""
    echo "2. Route53 Name Servers (update these in your domain registrar):"
    terraform output route53_name_servers 2>/dev/null || echo "⚠️  Run 'terraform output route53_name_servers' to get nameservers"
    
else
    echo "❌ Infrastructure NOT deployed - Run 'terraform apply' first"
    exit 1
fi

echo ""
echo "3. DNS Resolution Tests:"

# Test main domain
echo "Testing ${DOMAIN}..."
if nslookup ${DOMAIN} >/dev/null 2>&1; then
    echo "✅ ${DOMAIN} resolves"
else
    echo "❌ ${DOMAIN} does not resolve"
fi

# Test subdomains
echo "Testing ${JENKINS_SUBDOMAIN}..."
if nslookup ${JENKINS_SUBDOMAIN} >/dev/null 2>&1; then
    echo "✅ ${JENKINS_SUBDOMAIN} resolves"
else
    echo "❌ ${JENKINS_SUBDOMAIN} does not resolve"
fi

echo "Testing ${VAULT_SUBDOMAIN}..."
if nslookup ${VAULT_SUBDOMAIN} >/dev/null 2>&1; then
    echo "✅ ${VAULT_SUBDOMAIN} resolves"
else
    echo "❌ ${VAULT_SUBDOMAIN} does not resolve"
fi

echo ""
echo "4. Service Accessibility Tests:"

# Test Jenkins
echo "Testing Jenkins service..."
if curl -I "http://${JENKINS_SUBDOMAIN}" --max-time 10 >/dev/null 2>&1; then
    echo "✅ Jenkins is accessible via HTTP"
else
    echo "❌ Jenkins is not accessible via HTTP"
fi

# Test Vault
echo "Testing Vault service..."
if curl -I "http://${VAULT_SUBDOMAIN}" --max-time 10 >/dev/null 2>&1; then
    echo "✅ Vault is accessible via HTTP"
else
    echo "❌ Vault is not accessible via HTTP"
fi

echo ""
echo "5. AWS Resources Status:"

# Check if EC2 instances are running
echo "Checking EC2 instances..."
terraform show | grep -A 5 "aws_instance" | grep "instance_state" || echo "Instance states not available"

echo ""
echo "6. Load Balancer Status:"
terraform show | grep -A 3 "aws_elb" | grep "dns_name" || echo "ELB DNS names not available"

echo ""
echo "================================================="
echo "Troubleshooting Steps if Issues Found:"
echo "================================================="
echo "1. If infrastructure not deployed: Run 'terraform apply'"
echo "2. If DNS not resolving: Update nameservers at your domain registrar"
echo "3. If services not accessible: Check EC2 instance status and security groups"
echo "4. Wait 5-10 minutes after deployment for DNS propagation"
echo "5. Try accessing via IP addresses first (check terraform outputs)"
echo "================================================="