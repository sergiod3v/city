#!/bin/bash
# Stop Bijadillo staging EC2 to save costs.
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

if [[ "$STATE" == "stopped" ]]; then
  echo "Already stopped."
  exit 0
fi

echo "Stopping $INSTANCE_ID (current: $STATE)..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --output text > /dev/null
echo "Waiting..."
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Stopped."
