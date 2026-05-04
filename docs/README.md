# City — Infrastructure Monorepo

Terraform infra for the ECCENSIA stack. Two business branches, one repo.

## What Lives Here

| Environment | Path | What It Runs |
|-------------|------|-------------|
| Trading (Behemoth) | `environments/trading/` | Binance DCA bot, PostgreSQL, EC2 |
| Consulting (AIejo Agency) | `environments/consulting/` | n8n per-client, ECS Fargate, RDS |

## Docs Index

| Doc | What It Covers |
|-----|---------------|
| [architecture.md](architecture.md) | Full infra diagram, decisions, cost |
| [bootstrap.md](bootstrap.md) | Pre-Terraform manual AWS setup (one-time, already done) |
| [cicd.md](cicd.md) | GitHub Actions plan/apply workflow, OIDC auth |
| [mac-onboarding.md](mac-onboarding.md) | Setting up a new machine to work with this repo |
| [mcp-servers.md](mcp-servers.md) | Claude MCP server config (GitHub, AWS docs, Context7, Postgres) |

## Quick State

- **AWS Account:** `670074751531` (us-east-1)
- **IAM User:** `sergio-admin`
- **SSH Key:** `~/.ssh/id_ed25519_alejocc` (Ed25519, used for EC2 + GitHub)
- **Active sprint:** Trading staging — Terraform written, CI/CD wired, awaiting first apply
- **Consulting:** Parked. Behemoth first.

## Repo Structure

```
city/
├── environments/
│   ├── trading/
│   │   └── staging/          ← active: 21 resources, plan verified clean
│   │       ├── BOOTSTRAP.md  ← pre-Terraform steps reference
│   │       ├── backend.tf
│   │       ├── versions.tf
│   │       ├── variables.tf
│   │       ├── networking.tf
│   │       ├── security_groups.tf
│   │       ├── ec2.tf
│   │       ├── iam.tf
│   │       ├── rds.tf
│   │       ├── cloudwatch.tf
│   │       └── outputs.tf
│   └── consulting/
│       └── documentation.md  ← parked, design only
├── docs/                     ← you are here
└── .github/
    └── workflows/
        └── terraform-staging.yml
```
