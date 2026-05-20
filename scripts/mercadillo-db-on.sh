#!/bin/bash
# Start Mercadillo staging RDS. Run before development sessions.
# Costs ~$15/mo while running — stop when done.
set -e

INSTANCE_ID="mercadillo-staging"
REGION="eu-west-1"

STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$STATUS" == "NOT_FOUND" ]]; then
  echo "ERROR: RDS instance '$INSTANCE_ID' not found. Run terraform apply first." >&2
  exit 1
fi

if [[ "$STATUS" == "available" ]]; then
  echo "$INSTANCE_ID is already running."
  exit 0
fi

if [[ "$STATUS" == "stopping" ]]; then
  echo "Instance is stopping. Wait for it to fully stop before starting."
  exit 1
fi

echo "Starting $INSTANCE_ID (current: $STATUS)..."
aws rds start-db-instance \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --output text --query "DBInstance.DBInstanceStatus"

echo "Waiting for available..."
aws rds wait db-instance-available \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION"

ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "Ready: $ENDPOINT:5432"
