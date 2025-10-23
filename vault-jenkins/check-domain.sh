#!/bin/bash

# Check domain configuration for SSL certificate validation
echo "🔍 Checking domain configuration for fiifiquaison.space..."

echo ""
echo "1. Checking Route53 hosted zones..."
aws route53 list-hosted-zones --query "HostedZones[?contains(Name, 'fiifiquaison')]" --output table

echo ""
echo "2. Checking if hosted zone exists for fiifiquaison.space..."
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='fiifiquaison.space.'].Id" --output text | sed 's|/hostedzone/||')

if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ]; then
    echo "✅ Hosted zone found: $ZONE_ID"
    
    echo ""
    echo "3. Checking NS records for the zone..."
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" --query "ResourceRecordSets[?Type=='NS']" --output table
else
    echo "❌ No hosted zone found for fiifiquaison.space"
    echo ""
    echo "🛠️  You need to create a hosted zone first:"
    echo "aws route53 create-hosted-zone --name fiifiquaison.space --caller-reference $(date +%s)"
fi

echo ""
echo "4. Testing domain resolution..."
nslookup fiifiquaison.space 8.8.8.8 || echo "❌ Domain not resolving"

echo ""
echo "5. Checking ACM certificates in eu-west-3..."
aws acm list-certificates --region eu-west-3 --query "CertificateSummaryList[?contains(DomainName, 'fiifiquaison')]" --output table