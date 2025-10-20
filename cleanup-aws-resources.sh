#!/bin/bash

# Comprehensive AWS Resource Cleanup Script
# This script will clean up all resources created for the Pet Adoption Auto Discovery project
# Enhanced version with better error handling and logging

set -euo pipefail

REGION="eu-west-3"
PROJECT_TAG="Fiifi-Pet-Adoption-Auto-Discovery"
LOG_FILE="cleanup-$(date +%Y%m%d-%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}" | tee -a "$LOG_FILE"
}

echo "🧹 Starting comprehensive AWS resource cleanup..."
echo "Region: $REGION"
echo "Project: $PROJECT_TAG"
echo "Log file: $LOG_FILE"

# Delete Route53 records first (except NS and SOA)
echo "🌐 Cleaning up Route53 records..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='fiifiquaison.space.'].Id" --output text | sed 's|/hostedzone/||')
if [ ! -z "$HOSTED_ZONE_ID" ]; then
    echo "Found hosted zone: $HOSTED_ZONE_ID"
    
    # Get all records except NS and SOA
    aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --query "ResourceRecordSets[?Type!='NS' && Type!='SOA']" > /tmp/records.json
    
    # Delete each record
    while read -r record; do
        if [ ! -z "$record" ] && [ "$record" != "null" ]; then
            echo "Deleting record: $record"
            aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":$record}]}" || true
        fi
    done < <(cat /tmp/records.json | jq -c '.[]')
    
    # Wait a bit for propagation
    sleep 10
    
    # Delete the hosted zone
    echo "Deleting hosted zone..."
    aws route53 delete-hosted-zone --id "$HOSTED_ZONE_ID" || true
fi

# Delete ACM certificates
echo "🔒 Deleting ACM certificates..."
CERT_ARNS=$(aws acm list-certificates --region $REGION --query "CertificateSummaryList[?DomainName=='fiifiquaison.space'].CertificateArn" --output text)
for cert in $CERT_ARNS; do
    echo "Deleting certificate: $cert"
    aws acm delete-certificate --region $REGION --certificate-arn $cert || true
done

# Wait for NAT gateways to delete
echo "⏳ Waiting for NAT gateways to finish deleting..."
while true; do
    NAT_COUNT=$(aws ec2 describe-nat-gateways --region $REGION --query "NatGateways[?Tags[?Key=='Project' && Value=='$PROJECT_TAG'] && State!='deleted'].NatGatewayId" --output text | wc -w)
    if [ $NAT_COUNT -eq 0 ]; then
        break
    fi
    echo "Still waiting for $NAT_COUNT NAT gateways to delete..."
    sleep 10
done

# Release Elastic IPs
echo "🌐 Releasing Elastic IPs..."
EIP_ALLOCS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].AllocationId" --output text)
for eip in $EIP_ALLOCS; do
    echo "Releasing EIP: $eip"
    aws ec2 release-address --region $REGION --allocation-id $eip || true
done

# Delete route tables (except main)
echo "🛣️ Deleting route tables..."
ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION --query "RouteTables[?Tags[?Key=='Project' && Value=='$PROJECT_TAG'] && !Associations[?Main==\`true\`]].RouteTableId" --output text)
for rt in $ROUTE_TABLES; do
    echo "Deleting route table: $rt"
    # First disassociate
    aws ec2 describe-route-tables --region $REGION --route-table-ids $rt --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" --output text | while read assoc; do
        if [ ! -z "$assoc" ]; then
            aws ec2 disassociate-route-table --region $REGION --association-id $assoc || true
        fi
    done
    aws ec2 delete-route-table --region $REGION --route-table-id $rt || true
done

# Delete internet gateway
echo "🌐 Deleting internet gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --region $REGION --query "InternetGateways[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].InternetGatewayId" --output text)
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].VpcId" --output text)
if [ ! -z "$IGW_ID" ] && [ ! -z "$VPC_ID" ]; then
    echo "Detaching and deleting IGW: $IGW_ID from VPC: $VPC_ID"
    aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID || true
    aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW_ID || true
fi

# Delete subnets
echo "🏗️ Deleting subnets..."
SUBNETS=$(aws ec2 describe-subnets --region $REGION --query "Subnets[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].SubnetId" --output text)
for subnet in $SUBNETS; do
    echo "Deleting subnet: $subnet"
    aws ec2 delete-subnet --region $REGION --subnet-id $subnet || true
done

# Delete VPC
echo "🏠 Deleting VPC..."
if [ ! -z "$VPC_ID" ]; then
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID || true
fi

# Delete key pair
echo "🔑 Deleting key pairs..."
aws ec2 delete-key-pair --region $REGION --key-name "fiifi-pet-adoption-auto-discovery-key" || true

# Delete KMS key
echo "🔐 Deleting KMS keys..."
KMS_KEYS=$(aws kms list-keys --region $REGION --query "Keys[].KeyId" --output text)
for key in $KMS_KEYS; do
    TAGS=$(aws kms list-resource-tags --region $REGION --key-id $key --query "Tags[?TagKey=='Project' && TagValue=='$PROJECT_TAG']" --output text 2>/dev/null || echo "")
    if [ ! -z "$TAGS" ]; then
        echo "Scheduling KMS key deletion: $key"
        aws kms schedule-key-deletion --region $REGION --key-id $key --pending-window-in-days 7 || true
    fi
done

# Delete IAM resources
echo "👤 Deleting IAM resources..."
# Detach policies and delete roles
for role in "fiifi-pet-adoption-auto-discovery-ssm-jenkins-role" "fiifi-pet-adoption-auto-discovery-ssm-vault-role"; do
    echo "Processing role: $role"
    
    # Detach managed policies
    aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null | while read policy; do
        if [ ! -z "$policy" ]; then
            echo "Detaching policy $policy from role $role"
            aws iam detach-role-policy --role-name $role --policy-arn $policy || true
        fi
    done
    
    # Delete inline policies
    aws iam list-role-policies --role-name $role --query "PolicyNames[]" --output text 2>/dev/null | while read policy; do
        if [ ! -z "$policy" ]; then
            echo "Deleting inline policy $policy from role $role"
            aws iam delete-role-policy --role-name $role --policy-name $policy || true
        fi
    done
    
    # Remove role from instance profiles
    aws iam list-instance-profiles-for-role --role-name $role --query "InstanceProfiles[].InstanceProfileName" --output text 2>/dev/null | while read profile; do
        if [ ! -z "$profile" ]; then
            echo "Removing role $role from instance profile $profile"
            aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name $role || true
        fi
    done
    
    # Delete the role
    echo "Deleting role: $role"
    aws iam delete-role --role-name $role || true
done

# Delete instance profiles
for profile in "fiifi-pet-adoption-auto-discovery-ssm-jenkins-profile" "fiifi-pet-adoption-auto-discovery-ssm-vault-instance-profile"; do
    echo "Deleting instance profile: $profile"
    aws iam delete-instance-profile --instance-profile-name $profile || true
done

# Clean up local files
print_status "$BLUE" "🗂️ Cleaning up local files..."
cd "$PROJECT_ROOT" 2>/dev/null || true

# Clean up any generated keys for security
find . -name "*.pem" -type f -delete 2>/dev/null || true
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/ 2>/dev/null || true

# Clean up in terraform directory
cd "$PROJECT_ROOT/vault-jenkins" 2>/dev/null || true
find . -name "*.pem" -type f -delete 2>/dev/null || true
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/ 2>/dev/null || true

print_status "$GREEN" "🔒 SSH keys cleaned up for security"

echo "✅ Cleanup completed!"
echo "Note: Some resources like KMS keys are scheduled for deletion and will be deleted after the waiting period."
echo "Please verify all resources have been deleted in the AWS console."