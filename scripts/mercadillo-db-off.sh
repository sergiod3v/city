#!/bin/bash
# Stop Mercadillo staging RDS. Run after development sessions to avoid cost.
# Saves ~$15/mo when stopped.
set -e

INSTANCE_ID="mercadillo-staging"
REGION="eu-west-1"

STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$STATUS" == "NOT_FOUND" ]]; then
  echo "ERROR: RDS instance '$INSTANCE_ID' not found." >&2
  exit 1
fi

if [[ "$STATUS" == "stopped" ]]; then
  echo "$INSTANCE_ID is already stopped."
  exit 0
fi

if [[ "$STATUS" == "starting" ]]; then
  echo "Instance is starting up. Wait for 'available' before stopping."
  exit 1
fi

echo "Stopping $INSTANCE_ID (current: $STATUS)..."
aws rds stop-db-instance \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --output text --query "DBInstance.DBInstanceStatus"

echo "Stopping... (takes ~2 min, no need to wait)"
