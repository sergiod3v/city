# Architecture — Trading Staging

EC2 was destroyed in commit `6924ea1` (trading-teardown). Behemoth now runs on the Hetzner VPS via Docker Compose. AWS surface is now SSM-only.

## What's Deployed

```
Hetzner CPX11 (Ubuntu 24.04)
└── /opt/apps/eccensia/  (docker compose, mirrors city/config/eccensia/)
    ├── nginx          — reverse proxy (HTTP only)
    ├── eccensia       — Vite SPA   (ghcr.io/sergiod3v/eccensia:latest)
    └── behemoth       — bot         (ghcr.io/sergiod3v/auto-trading:latest)
        ├── volume behemoth_data → /app/data (SQLite)
        └── reads SSM via AWS creds in /opt/apps/eccensia/.env
```

See `docs/deployment.md` for the deploy runbook and `docs/services.md` for the service map.

## Storage

SQLite at `/app/data/behemoth.db` inside the `behemoth` container. Docker named volume `behemoth_data` persists across `up -d` restarts. No RDS in staging.

## Secrets — SSM Parameter Store (eu-west-1)

All `SecureString`, AWS-managed `aws/ssm` key.

| Parameter | Who fills |
|-----------|----------|
| `behemoth.staging.binance.apiKey` | Manual |
| `behemoth.staging.binance.secret` | Manual |
| `behemoth.staging.binance.privateKey` | Manual (Ed25519, for prod) |
| `behemoth.staging.slack.webhookUrl` | Manual (deprecated, kept for backcompat) |

## IAM

IAM user `sergio-admin` access keys live in `/opt/apps/eccensia/.env` on the VPS. Scope is broader than ideal — replace with a tight `ssm:GetParameter` user when revisiting. The previous EC2 instance-profile role (`behemoth-staging-ec2`) was destroyed with the EC2.

OIDC role `behemoth-github-actions-terraform` still exists for Terraform applies via GitHub Actions.

## Tags (all AWS resources)

| Tag | Value |
|-----|-------|
| `project` | `auto-trading` |
| `env` | `staging` |
| `client` | `myself` |
| `managed_by` | `terraform` |

## Terraform State

- Backend: S3 `eccensia-tfstate-trading-staging`
- No DynamoDB lock — solo dev, single pipeline

## Cost

| Resource | Cost |
|----------|------|
| Hetzner CPX11 | ~$7/mo |
| SSM + S3 state | ~$1/mo |
| **Total** | **~$8/mo** |

## Key Decisions

| Decision | Why |
|----------|-----|
| Hetzner over EC2 | $7 vs $8.50, 2GB RAM vs 1GB, no Binance geo-block on DE. |
| SQLite over RDS | $0 vs $15/mo. Single-process bot. Add RDS for prod. |
| SSM over Secrets Manager | Free vs $0.40/secret/mo. |
| AWS-managed KMS only | Cannot be accidentally deleted. |
| Docker Compose, no orchestrator | Single-host, no need for ECS/k8s. |
| OIDC for GH Actions (Terraform) | No stored AWS keys for infra applies. |
