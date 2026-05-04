# City — Infrastructure Monorepo

Terraform for all ECCENSIA infrastructure. Single source of truth for infra state.

## Environments

| Path | What it runs | Status |
|------|-------------|--------|
| `environments/trading/staging/` | Behemoth bot, EC2, Docker | Live |
| `environments/consulting/` | AIejo Agency (ECS Fargate) | Parked |

## Docs

| File | Covers |
|------|--------|
| [architecture.md](architecture.md) | What's deployed, decisions, cost |
| [bootstrap.md](bootstrap.md) | One-time manual AWS setup (already done) |
| [cicd.md](cicd.md) | Plan/apply workflow via GitHub Actions |
| [mac-onboarding.md](mac-onboarding.md) | New machine setup |
| [mcp-servers.md](mcp-servers.md) | Claude MCP config |

## Scripts

```bash
# Start/stop EC2 to save cost when not in use
python scripts/manage.py auto-trading staging status
python scripts/manage.py auto-trading staging on
python scripts/manage.py auto-trading staging off
```

See `scripts/README.md` for full usage.
