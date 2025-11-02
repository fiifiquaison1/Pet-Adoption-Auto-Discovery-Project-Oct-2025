#!/bin/bash
# Comprehensive AWS resource cleanup after terraform destroy
set -euo pipefail
REGION="eu-west-3"
PROFILE="default"

# Destroy Terraform in all relevant directories
for dir in . vault-jenkins modules/ansible modules/bastion modules/database modules/nexus modules/prod-env modules/stage-env modules/sonarqube modules/vpc backend-setup; do
  if [[ -d "$dir" && -f "$dir/main.tf" ]]; then
    echo "Destroying Terraform resources in $dir..."
    (cd "$dir" && terraform init && terraform destroy -auto-approve)
  fi
done

# AWS CLI checks and cleanup
# EC2 instances
INSTANCES=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running --region $REGION --profile $PROFILE --query 'Reservations[].Instances[].InstanceId' --output text)
if [[ -n "$INSTANCES" ]]; then
  echo "Stopping EC2 instances: $INSTANCES"
  aws ec2 stop-instances --instance-ids $INSTANCES --region $REGION --profile $PROFILE
fi

# NAT Gateways
NATS=$(aws ec2 describe-nat-gateways --region $REGION --profile $PROFILE --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
for nat in $NATS; do
  echo "Deleting NAT Gateway: $nat"
  aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION --profile $PROFILE
  sleep 2
fi

# Elastic IPs
EIPS=$(aws ec2 describe-addresses --region $REGION --profile $PROFILE --query 'Addresses[].AllocationId' --output text)
for eip in $EIPS; do
  echo "Releasing Elastic IP: $eip"
  aws ec2 release-address --allocation-id $eip --region $REGION --profile $PROFILE
  sleep 1
fi

# Unattached EBS volumes
VOLS=$(aws ec2 describe-volumes --region $REGION --profile $PROFILE --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text)
for vol in $VOLS; do
  echo "Deleting EBS volume: $vol"
  aws ec2 delete-volume --volume-id $vol --region $REGION --profile $PROFILE
  sleep 1
fi

# Snapshots
SNAPS=$(aws ec2 describe-snapshots --owner-ids self --region $REGION --profile $PROFILE --query 'Snapshots[].SnapshotId' --output text)
for snap in $SNAPS; do
  echo "Deleting EBS snapshot: $snap"
  aws ec2 delete-snapshot --snapshot-id $snap --region $REGION --profile $PROFILE
  sleep 1
fi

# Load balancers (classic)
CLBS=$(aws elb describe-load-balancers --region $REGION --profile $PROFILE --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text)
for clb in $CLBS; do
  echo "Deleting classic load balancer: $clb"
  aws elb delete-load-balancer --load-balancer-name $clb --region $REGION --profile $PROFILE
  sleep 1
fi

# Load balancers (ALB/NLB)
ALBS=$(aws elbv2 describe-load-balancers --region $REGION --profile $PROFILE --query 'LoadBalancers[].LoadBalancerArn' --output text)
for alb in $ALBS; do
  echo "Deleting ALB/NLB: $alb"
  aws elbv2 delete-load-balancer --load-balancer-arn $alb --region $REGION --profile $PROFILE
  sleep 1
fi

echo "Cleanup complete. All Terraform and AWS resources should be destroyed."
