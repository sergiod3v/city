# ECCENSIA Infra Control

Single Hetzner VPS (`hetzner`, CPX11, Ubuntu 24.04) running all services via Docker Compose at `/opt/apps/eccensia/`.

AWS EC2 was retired in the trading-teardown migration. Behemoth + Eccensia frontend now run on the Hetzner box; Binance access works directly (no geo-block on Hetzner DE).

## SSH

```bash
ssh hetzner          # via ~/.ssh/config alias (see scripts/mac.sh)
```

`~/.ssh/config` entry (created by `scripts/mac.sh`):
```
Host hetzner
    HostName <vps-ip>
    User alejo
    IdentityFile ~/.ssh/hetzner_main
    IdentitiesOnly yes
```

## Service Control

All commands run `docker compose` on the host in `/opt/apps/eccensia/`.

```bash
ssh hetzner
cd /opt/apps/eccensia

docker compose ps                       # status
docker compose pull <service>           # latest image
docker compose up -d <service>          # apply
docker compose restart <service>
docker compose logs --tail 50 -f <service>
```

### Services

| Name | Image | Notes |
|------|-------|-------|
| `nginx` | `nginx:alpine` | Reverse proxy, HTTP only (TLS deferred) |
| `eccensia` | `ghcr.io/sergiod3v/eccensia:latest` | Vite SPA |
| `behemoth` | `ghcr.io/sergiod3v/auto-trading:latest` | Trading bot, reads SSM via AWS creds in `.env` |

Mercadillo (Next.js + Postgres) is not deployed on this host — slated for Cloudflare/separate stack.

## First-Deploy Bootstrap

See `config/eccensia/README.md`. Summary:

```bash
ssh hetzner
sudo mkdir -p /opt/apps/eccensia && sudo chown -R "$USER":"$USER" /opt/apps/eccensia
git clone git@github.com:sergiod3v/city.git ~/city
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/

cd /opt/apps/eccensia
cp .env.example .env && $EDITOR .env

echo "$GHCR_PAT" | docker login ghcr.io -u sergiod3v --password-stdin
docker compose pull && docker compose up -d
```

## Image Build → Deploy Flow

1. Push to `master` on `auto-trading` or `eccensia` → GitHub Actions builds + pushes `:latest` to GHCR.
2. No auto-pull on the host. Manual `docker compose pull <svc> && docker compose up -d <svc>` to apply.

## Config Changes

Compose file + nginx config + `.env.example` live in `city/config/eccensia/`. Workflow:

```bash
# Local
$EDITOR city/config/eccensia/...
git commit && git push

# On host
cd ~/city && git pull
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/ --exclude .env
cd /opt/apps/eccensia && docker compose up -d
```

## Git / Infra Change Policy

- **Never push to master directly** for Terraform changes — branch → PR → plan → merge → apply.
- Never commit `.tfvars` with real values (use `.tfvars.example`). Never commit `.env`.
- Never commit `.terraform/` directories.
- State backend: S3 (never local).
- Tag every AWS resource: `Project`, `Environment`, `Owner`, `ManagedBy=terraform`.
