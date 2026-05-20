#!/bin/bash
# Show Mercadillo staging RDS status and endpoint.
set -e

INSTANCE_ID="mercadillo-staging"
REGION="eu-west-1"

aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --region "$REGION" \
  --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Class:DBInstanceClass,Engine:EngineVersion}" \
  --output table 2>/dev/null || echo "Instance not found — not yet deployed."
