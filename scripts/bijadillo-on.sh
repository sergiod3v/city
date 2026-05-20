#!/bin/bash
# Start Bijadillo staging EC2. Run before development or when deploying.
# Costs ~$8.50/mo while running — stop when done.
set -e

REGION="eu-west-1"

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:project,Values=bijadillo" "Name=tag:env,Values=staging" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$INSTANCE_ID" == "NOT_FOUND" || "$INSTANCE_ID" == "None" ]]; then
  echo "ERROR: Bijadillo EC2 not found. Run terraform apply first." >&2
  exit 1
fi

STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text)

if [[ "$STATE" == "running" ]]; then
  IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)
  echo "Already running: $IP"
  exit 0
fi

echo "Starting $INSTANCE_ID (current: $STATE)..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --output text > /dev/null
echo "Waiting..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Ready: $IP"
