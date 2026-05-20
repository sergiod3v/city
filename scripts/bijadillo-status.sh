#!/bin/bash
# Check Bijadillo staging EC2 status.
set -e

REGION="eu-west-1"

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:project,Values=bijadillo" "Name=tag:env,Values=staging" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$INSTANCE_ID" == "NOT_FOUND" || "$INSTANCE_ID" == "None" ]]; then
  echo "ERROR: Bijadillo EC2 not found." >&2
  exit 1
fi

STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text)

IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Instance: $INSTANCE_ID"
echo "State:    $STATE"
echo "IP:       $IP"
