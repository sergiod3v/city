# Trading Environment -- Infrastructure Documentation

## Purpose
Hosts Behemoth, the ECCENSIA automated DCA trading bot. Runs 24/7 against Binance via CCXT Pro.

## Environments

| Env | Purpose | Instance | Cost |
|-----|---------|---------|------|
| `staging` | Paper trading (testnet), infra changes | t3.micro | ~$5/mo |
| `prod` | Live trading, real funds | t3.small Reserved 1yr | ~$8/mo |

## AWS Architecture

```
VPC (trading-vpc)
└── Public subnet
    └── EC2 (Behemoth bot + PM2 + n8n)
        └── Security Group: port 22 (my IP only), port 5678 (n8n, my IP only)
RDS PostgreSQL t3.micro (trading-db)
    └── Private subnet, no public access
AWS Secrets Manager
    └── binance-api-key (apiKey, secret, paper_mode flag)
    └── slack-webhook-url
CloudWatch
    └── Log groups: /behemoth/bot, /behemoth/errors
    └── Alarms: CPU >80%, error rate, circuit breaker trigger
```

## Binance Connectivity

### Paper Trading (Staging)
- **Environment:** Binance Spot Demo Trading (`demo-api.binance.com`)
- **API keys:** Separate testnet keys — NEVER share with prod keys
- **CCXT config:**
  ```python
  exchange = ccxt.pro.binance({
      'apiKey': secrets['testnet_api_key'],
      'secret': secrets['testnet_secret'],
      'options': {'defaultType': 'spot'},
  })
  # Override URLs for demo endpoint (ccxt sandbox_mode uses old testnet.binance.vision)
  exchange.urls['api']['public'] = 'https://demo-api.binance.com/api/v3'
  exchange.urls['api']['private'] = 'https://demo-api.binance.com/api/v3'
  ```
- **WebSocket (market data):** `wss://demo-stream.binance.com`
- **WebSocket (trade):** `wss://demo-ws-api.binance.com`

### Live Trading (Prod)
- **API key restrictions (mandatory):**
  - IP whitelist: EC2 Elastic IP only
  - Spot trading: ENABLED
  - Withdrawals: DISABLED (always)
  - Futures: DISABLED (bot is spot only)
- **Key type:** Ed25519 asymmetric (HMAC deprecated by Binance)
- **Storage:** AWS Secrets Manager → `binance/prod/api-keys`
- **Rotation:** Every 90 days, coordinated with bot restart via PM2

## Secrets Access Pattern (EC2)
EC2 instance profile has `secretsmanager:GetSecretValue` on ARN prefix `arn:aws:secretsmanager:us-east-1:*:secret:binance/*`.

```python
import boto3, json

def get_binance_secrets(paper_mode: bool) -> dict:
    client = boto3.client('secretsmanager', region_name='us-east-1')
    secret_id = 'binance/staging/api-keys' if paper_mode else 'binance/prod/api-keys'
    return json.loads(client.get_secret_value(SecretId=secret_id)['SecretString'])
```

## Paper vs Live Mode Switch
Controlled by a single env var `BEHEMOTH_PAPER_MODE=true|false` set in PM2 ecosystem config.
Bot reads this at startup → selects correct secret ARN → configures CCXT URLs accordingly.
Never use live keys in staging. Never use testnet keys in prod.

## Database
- Engine: PostgreSQL 15, t3.micro
- Private subnet — accessible only from EC2 security group
- Key tables: `cycles`, `rungs`, `events`, `portfolio_snapshots`
- Backups: RDS automated, 7-day retention
- COP tracking: all trades store `cop_rate_at_fill` for DIAN tax reporting

## Terraform State
- Backend: S3 bucket `eccensia-tfstate-trading-prod` (prod), `eccensia-tfstate-trading-staging` (staging)
- Lock: DynamoDB table `eccensia-tfstate-lock`
- Never use local state.

## Deployment
1. GitHub Actions pushes to `main` → SSH into EC2 → `git pull && pm2 restart behemoth`
2. Infra changes: `terraform plan` in staging → review → `terraform apply` in prod
3. Zero-downtime: PM2 cluster mode with reload (not restart) for non-breaking changes

## Monthly Cost Estimate (Prod)
| Resource | Cost |
|----------|------|
| EC2 t3.small Reserved | ~$8 |
| RDS t3.micro | ~$15 |
| Secrets Manager | ~$2 |
| CloudWatch | ~$5 |
| Data transfer | ~$1 |
| **Total** | **~$31** |

## Tagging Convention
```
Project     = behemoth
Environment = staging | prod
Owner       = alejocc
ManagedBy   = terraform
```
