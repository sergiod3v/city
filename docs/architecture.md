# Architecture — Trading Staging

## What's Deployed

```
AWS 670074751531 / us-east-1
│
└── Default VPC (no custom VPC)
    └── EC2 t3.micro — behemoth-staging-bot
        ├── Docker: ghcr.io/sergiod3v/auto-trading:latest
        ├── SQLite: /opt/behemoth/data/behemoth.db (volume → /app/data inside container)
        └── EIP: 52.73.213.253 (static — whitelisted on Binance API key)
```

## Security

| Resource | Rule |
|----------|------|
| EC2 SG | Port 22 from operator IP only (secret `MY_IP_CIDR`) |
| No public RDS | Not used in staging |
| IMDSv2 | Required. hop_limit=2 so Docker container inherits IAM role |

## EC2

- AMI: Amazon Linux 2023 (latest, resolved via `data "aws_ami"`)
- Instance: t3.micro on-demand (~$8.50/mo)
- User data: installs Docker, creates `/opt/behemoth/data`
- No PM2, no Python on host — bot runs entirely inside Docker

## Storage

SQLite at `/opt/behemoth/data/behemoth.db` on EC2.
Docker volume: `-v /opt/behemoth/data:/app/data` — survives container restarts and redeploys.
No RDS in staging. RDS added only in prod when real money and multi-process access are needed.

## Secrets — SSM Parameter Store

All `SecureString` encrypted with AWS-managed `aws/ssm` key (cannot be deleted by you).

| Parameter | Managed by | Value |
|-----------|-----------|-------|
| `behemoth.staging.binance.apiKey` | Manual | Binance demo HMAC key |
| `behemoth.staging.binance.secret` | Manual | Binance demo HMAC secret |
| `behemoth.staging.binance.privateKey` | Manual | Ed25519 private key (for prod) |
| `behemoth.staging.slack.webhookUrl` | Manual | Slack webhook |

## IAM

Role `behemoth-staging-ec2`:
- `ssm:GetParameter` on `behemoth.staging.*` only
- `kms:Decrypt` on `aws/ssm` (AWS-managed, cannot be lost)
- `logs:PutLogEvents` on `/behemoth/staging/*`

## Tags (all resources)

```
project    = auto-trading
env        = staging          ← injected via TF_VAR_env, dynamic per environment
client     = myself
managed_by = terraform
```

Plus `Name` tag per resource with `${var.env}` interpolation.

## Terraform State

- Backend: S3 `eccensia-tfstate-trading-staging`
- No DynamoDB lock — solo dev, single pipeline, no concurrent applies
- Key: `trading/staging/terraform.tfstate`

## Cost

| Resource | Cost |
|----------|------|
| EC2 t3.micro on-demand | ~$8.50/mo |
| EIP (attached to running instance) | $0 |
| SSM, CloudWatch, S3 state | ~$0.50/mo |
| **Total** | **~$9/mo** |

## Key Decisions

| Decision | Why |
|----------|-----|
| Default VPC | No benefit to custom VPC for a single-instance bot. Saves 5+ resources. |
| SQLite over RDS | $0 vs $15/mo. Single-process bot doesn't need remote DB. Add RDS for prod. |
| SSM over Secrets Manager | Free vs $0.40/secret/mo. |
| On-demand instances | No upfront commitment. Reassess for prod after 6 stable months. |
| AWS-managed KMS only | CMKs can be deleted → data loss. AWS-managed keys cannot. |
| No DynamoDB lock | Solo dev, single CI pipeline. Lock adds cost with zero benefit. |
| Docker not PM2 | Portable, reproducible, no host Python dependency. Image = single deploy artifact. |
| OIDC for GH Actions | No stored AWS keys. Credentials live 15 min per job. |
