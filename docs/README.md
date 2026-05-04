# City — Infrastructure Monorepo

Terraform for all ECCENSIA infrastructure. Source of truth for infra state.

## Environments

| Path | What it runs | Status |
|------|-------------|--------|
| `environments/trading/staging/` | Behemoth bot, EC2, Docker | Live |
| `environments/consulting/` | AIejo Agency (ECS Fargate) | Parked |

## Docs

| File | Covers |
|------|--------|
| [architecture.md](architecture.md) | What's deployed, why each decision was made |
| [bootstrap.md](bootstrap.md) | One-time manual AWS setup (already done) |
| [cicd.md](cicd.md) | How plan/apply works via GitHub Actions |
| [mac-onboarding.md](mac-onboarding.md) | New machine setup |
| [mcp-servers.md](mcp-servers.md) | Claude MCP config |

## Current State

- **AWS:** `670074751531` / `us-east-1` / user `sergio-admin`
- **Staging EC2:** `52.73.213.253` (EIP, static)
- **SSH:** `ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@52.73.213.253`
- **Bot image:** `ghcr.io/sergiod3v/auto-trading:latest`
- **Monthly cost:** ~$9/mo (EC2 t3.micro on-demand)
