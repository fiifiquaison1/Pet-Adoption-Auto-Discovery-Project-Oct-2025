#!/bin/bash

# Troubleshooting Script for Fiifi Pet Adoption Auto Discovery Project
# This script helps diagnose why Jenkins/Vault servers might not be coming up

echo "🔍 Pet Adoption Auto Discovery - Server Troubleshooting"
echo "======================================================="
echo ""

# Configuration
AWS_REGION="eu-west-3"
PROJECT_NAME="fiifi-pet-adoption-auto-discovery"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${1}${2}${NC}"; }

echo "📍 Checking infrastructure status in region: $AWS_REGION"
echo ""

# Check if instances exist
print_status "$BLUE" "1. Checking EC2 Instances..."
JENKINS_INSTANCE=$(aws ec2 describe-instances --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-jenkins-server" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
  --output table 2>/dev/null)

VAULT_INSTANCE=$(aws ec2 describe-instances --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-vault-server" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
  --output table 2>/dev/null)

if [[ -n "$JENKINS_INSTANCE" && "$JENKINS_INSTANCE" != *"None"* ]]; then
  print_status "$GREEN" "✅ Jenkins instance found:"
  echo "$JENKINS_INSTANCE"
else
  print_status "$RED" "❌ Jenkins instance not found or not running"
fi

echo ""

if [[ -n "$VAULT_INSTANCE" && "$VAULT_INSTANCE" != *"None"* ]]; then
  print_status "$GREEN" "✅ Vault instance found:"
  echo "$VAULT_INSTANCE"
else
  print_status "$RED" "❌ Vault instance not found or not running"
fi

echo ""

# Check VPC and subnets
print_status "$BLUE" "2. Checking VPC Configuration..."
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  print_status "$GREEN" "✅ VPC found: $VPC_ID"
  
  # Check subnets
  SUBNETS=$(aws ec2 describe-subnets --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" \
    --output table 2>/dev/null)
  
  print_status "$GREEN" "📋 Subnets in VPC:"
  echo "$SUBNETS"
else
  print_status "$RED" "❌ VPC not found"
fi

echo ""

# Check security groups
print_status "$BLUE" "3. Checking Security Groups..."
JENKINS_SG=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=${PROJECT_NAME}-jenkins-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

VAULT_SG=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=${PROJECT_NAME}-vault-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [[ -n "$JENKINS_SG" && "$JENKINS_SG" != "None" ]]; then
  print_status "$GREEN" "✅ Jenkins security group: $JENKINS_SG"
else
  print_status "$RED" "❌ Jenkins security group not found"
fi

if [[ -n "$VAULT_SG" && "$VAULT_SG" != "None" ]]; then
  print_status "$GREEN" "✅ Vault security group: $VAULT_SG"
else
  print_status "$RED" "❌ Vault security group not found"
fi

echo ""

# Check Load Balancers
print_status "$BLUE" "4. Checking Load Balancers..."
JENKINS_ELB=$(aws elb describe-load-balancers --region $AWS_REGION \
  --query "LoadBalancerDescriptions[?contains(LoadBalancerName, 'jenkins')].LoadBalancerName" \
  --output text 2>/dev/null)

VAULT_ELB=$(aws elb describe-load-balancers --region $AWS_REGION \
  --query "LoadBalancerDescriptions[?contains(LoadBalancerName, 'vault')].LoadBalancerName" \
  --output text 2>/dev/null)

if [[ -n "$JENKINS_ELB" && "$JENKINS_ELB" != "None" ]]; then
  print_status "$GREEN" "✅ Jenkins ELB: $JENKINS_ELB"
else
  print_status "$RED" "❌ Jenkins ELB not found"
fi

if [[ -n "$VAULT_ELB" && "$VAULT_ELB" != "None" ]]; then
  print_status "$GREEN" "✅ Vault ELB: $VAULT_ELB"
else
  print_status "$RED" "❌ Vault ELB not found"
fi

echo ""

# Check Route53 records
print_status "$BLUE" "5. Checking DNS Records..."
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='fiifiquaison.space.'].Id" --output text | sed 's|/hostedzone/||' 2>/dev/null)

if [[ -n "$ZONE_ID" && "$ZONE_ID" != "None" ]]; then
  print_status "$GREEN" "✅ Route53 hosted zone: $ZONE_ID"
  
  JENKINS_RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
    --query "ResourceRecordSets[?Name=='jenkins.fiifiquaison.space.']" --output table 2>/dev/null)
  
  if [[ -n "$JENKINS_RECORD" && "$JENKINS_RECORD" != *"[]"* ]]; then
    print_status "$GREEN" "✅ Jenkins DNS record exists"
  else
    print_status "$RED" "❌ Jenkins DNS record not found"
  fi
else
  print_status "$RED" "❌ Route53 hosted zone not found"
fi

echo ""

# Check Terraform state
print_status "$BLUE" "6. Checking Terraform Status..."
if [[ -d "vault-jenkins" ]]; then
  cd vault-jenkins
  
  if terraform show &>/dev/null; then
    print_status "$GREEN" "✅ Terraform state file exists"
    
    print_status "$BLUE" "📋 Terraform Resources:"
    terraform state list 2>/dev/null | head -10
  else
    print_status "$RED" "❌ No Terraform state found"
  fi
  
  cd ..
else
  print_status "$RED" "❌ vault-jenkins directory not found"
fi

echo ""
echo "🎯 Troubleshooting Complete!"
echo ""
print_status "$YELLOW" "💡 Common Issues & Solutions:"
echo "   1. VPC Module: Ensure private_subnet_cidrs = [] if not needed"
echo "   2. User Data: Check for script errors in EC2 console"
echo "   3. Security Groups: Verify ports 8080 (Jenkins) and 8200 (Vault) are open"
echo "   4. SSL Certificates: Check ACM certificate validation status"
echo "   5. Route53: Ensure hosted zone exists for fiifiquaison.space"
echo ""
print_status "$BLUE" "🔧 Next Steps:"
echo "   - Check EC2 Console for instance status and system logs"
echo "   - Verify user data script execution in CloudWatch logs"
echo "   - Test direct instance access via SSH before ELB"