#!/bin/bash
# Complete ECCENSIA infra on/off — controls the single shared EC2.
# All services collocated: Behemoth bot + Bijadillo (nginx + mercadillo + postgres).
#
# Usage:
#   ./infra.sh up       Start EC2, wait until running, print IP + cost reminder
#   ./infra.sh down     Stop EC2 (EIP retained, Binance whitelist preserved)
#   ./infra.sh status   EC2 state + uptime + EIP

set -euo pipefail

REGION="eu-west-1"
ENV="${ENV:-staging}"

# ─── Resolve instance ─────────────────────────────────────────────────────────

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=behemoth-${ENV}-bot" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null)

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "ERROR: EC2 not found (tag Name=behemoth-${ENV}-bot). Run terraform apply first." >&2
  exit 1
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────

get_state() {
  aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text
}

get_eip() {
  aws ec2 describe-addresses \
    --filters "Name=instance-id,Values=${INSTANCE_ID}" \
    --region "$REGION" \
    --query "Addresses[0].PublicIp" \
    --output text 2>/dev/null || echo "—"
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_up() {
  STATE=$(get_state)
  if [[ "$STATE" == "running" ]]; then
    EIP=$(get_eip)
    echo "Already running  instance=$INSTANCE_ID  ip=$EIP"
    exit 0
  fi

  echo "Starting $INSTANCE_ID  (state: $STATE)..."
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --output text > /dev/null
  echo "Waiting for running state..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

  EIP=$(get_eip)
  echo ""
  echo "  UP  instance=$INSTANCE_ID  ip=$EIP"
  echo ""
  echo "Services:"
  echo "  Behemoth bot   — starts automatically via systemd/docker run"
  echo "  Bijadillo stack — cd /opt/bijadillo && docker compose up -d"
  echo ""
  echo "Cost: ~\$0.012/hr (~\$8.50/mo) while running. Stop when done: ./infra.sh down"
}

cmd_down() {
  STATE=$(get_state)
  if [[ "$STATE" == "stopped" ]]; then
    echo "Already stopped  instance=$INSTANCE_ID"
    exit 0
  fi

  EIP=$(get_eip)
  echo "Stopping $INSTANCE_ID  (ip=$EIP, state=$STATE)..."
  aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --output text > /dev/null
  echo "Waiting for stopped state..."
  aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"

  echo ""
  echo "  DOWN  instance=$INSTANCE_ID"
  echo "  EIP $EIP retained — Binance whitelist preserved."
  echo "  Cost while stopped: ~\$0.005/hr (EIP charge only)"
}

cmd_status() {
  STATE=$(get_state)
  EIP=$(get_eip)

  LAUNCH_TIME=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].LaunchTime" \
    --output text 2>/dev/null || echo "—")

  echo "instance  $INSTANCE_ID"
  echo "state     $STATE"
  echo "eip       $EIP"
  echo "launched  $LAUNCH_TIME"
  echo "region    $REGION"
  echo ""
  echo "Services on this EC2:"
  echo "  Behemoth (trading bot)       /opt/behemoth/"
  echo "  nginx + certbot              /opt/bijadillo/"
  echo "  mercadillo (Next.js :3000)   /opt/bijadillo/"
  echo "  postgres :5432               /opt/bijadillo/"
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  up)     cmd_up ;;
  down)   cmd_down ;;
  status) cmd_status ;;
  *)
    echo "Usage: $0 up|down|status"
    echo ""
    echo "  up      Start EC2 (all services)"
    echo "  down    Stop EC2 (EIP + Binance whitelist preserved)"
    echo "  status  Show EC2 state, IP, services"
    exit 1
    ;;
esac
