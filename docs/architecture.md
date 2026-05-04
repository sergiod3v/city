# Architecture — Trading Staging

## What's Deployed

```
AWS / us-east-1 / Default VPC
└── EC2 t3.micro — behemoth-staging-bot
    ├── Docker: ghcr.io/sergiod3v/auto-trading:latest
    ├── SQLite: /opt/behemoth/data/behemoth.db (volume → /app/data inside container)
    └── EIP (static — whitelisted on Binance API key)
```

## Security

| Resource | Rule |
|----------|------|
| EC2 SG | Port 22 from operator IP only (GitHub secret `MY_IP_CIDR`) |
| IMDSv2 | Required, hop_limit=2 so Docker container inherits IAM role |

## EC2

- AMI: Amazon Linux 2023 (latest, resolved dynamically — no hardcoded ID)
- Instance: t3.micro on-demand (~$8.50/mo)
- User data: installs Docker, creates `/opt/behemoth/data`
- No PM2, no Python on host — bot runs entirely inside Docker

## Storage

SQLite at `/opt/behemoth/data/behemoth.db` on EC2.
Docker volume `-v /opt/behemoth/data:/app/data` — survives restarts and redeploys.
No RDS in staging. Add RDS only for prod with real money and multi-process access.

## Secrets — SSM Parameter Store

All `SecureString` encrypted with AWS-managed `aws/ssm` key (cannot be deleted or disabled).

| Parameter | Who fills |
|-----------|----------|
| `behemoth.staging.binance.apiKey` | Manual |
| `behemoth.staging.binance.secret` | Manual |
| `behemoth.staging.binance.privateKey` | Manual (Ed25519, for prod) |
| `behemoth.staging.slack.webhookUrl` | Manual |

## IAM

Role `behemoth-staging-ec2`:
- `ssm:GetParameter` on `behemoth.staging.*` only
- `kms:Decrypt` on `aws/ssm` (AWS-managed)
- `logs:PutLogEvents` on `/behemoth/staging/*`
- Account ID resolved dynamically via `data.aws_caller_identity` — not hardcoded

## Tags (all resources)

| Tag | Value |
|-----|-------|
| `project` | `auto-trading` |
| `env` | `staging` (injected via `TF_VAR_env`, dynamic per environment) |
| `client` | `myself` |
| `managed_by` | `terraform` |

## Terraform State

- Backend: S3 `eccensia-tfstate-trading-staging`
- No DynamoDB lock — solo dev, single pipeline

## Cost

| Resource | Cost |
|----------|------|
| EC2 t3.micro on-demand | ~$8.50/mo |
| EIP (attached to running instance) | $0 |
| SSM, CloudWatch, S3 state | ~$0.50/mo |
| **Total (running)** | **~$9/mo** |
| **Total (stopped)** | **~$0.50/mo** |

Use `python scripts/manage.py auto-trading staging off` to stop EC2 when not in use.

## Key Decisions

| Decision | Why |
|----------|-----|
| Default VPC | No benefit for single-instance setup. Saves 5+ resources. |
| SQLite over RDS | $0 vs $15/mo. Single-process bot. Add RDS for prod. |
| SSM over Secrets Manager | Free vs $0.40/secret/mo. |
| On-demand over reserved | No upfront commitment at this stage. |
| AWS-managed KMS only | Cannot be accidentally deleted. |
| Docker not PM2 | Portable, reproducible, single deploy artifact. |
| OIDC for GH Actions | No stored AWS keys. Credentials live 15 min per job. |
| `data.aws_caller_identity` in IAM | No hardcoded account ID in public repo. |
