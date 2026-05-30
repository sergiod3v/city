# ECCENSIA Service Map

Hetzner CPX11 VPS hosts the Eccensia stack.
Host path: `/opt/apps/eccensia/`
Compose: `/opt/apps/eccensia/docker-compose.yml` (mirrors `city/config/eccensia/docker-compose.yml`)

## Service Table

| Service | Image | Internal Port | Exposure | Volume | Network(s) |
|---------|-------|--------------|----------|--------|------------|
| nginx | `nginx:alpine` | 80/443 host | reverse proxy (HTTP only today) | conf, certs, webroot (bind) | net_proxy |
| eccensia | `ghcr.io/sergiod3v/eccensia:latest` | 80 | via nginx | — | net_proxy |
| behemoth | `ghcr.io/sergiod3v/auto-trading:latest` | — | none (no inbound) | `behemoth_data` (sqlite) | net_behemoth |

Mercadillo / Postgres / certbot are not deployed on this host (planned for Cloudflare or a separate stack).

## Docker Networks

| Network | Members | Purpose |
|---------|---------|---------|
| net_proxy | nginx, eccensia | HTTP routing layer |
| net_behemoth | behemoth | Isolated — no inbound HTTP |

## TLS

Deferred. `nginx/conf.d/default.conf` keeps `/.well-known/acme-challenge/` open so certbot can be added later without restarting nginx. Previous multi-domain TLS config is in git history pre-VPS-migration.

## Build Pipelines

| Service | Repo | Workflow | Registry Tag |
|---------|------|----------|--------------|
| eccensia | sergiod3v/eccensia | `.github/workflows/build-push.yml` | `ghcr.io/sergiod3v/eccensia:latest` |
| behemoth | sergiod3v/auto-trading | `.github/workflows/build-deploy.yml` | `ghcr.io/sergiod3v/auto-trading:latest` + `:<sha>` |

Trigger: push to `master`. CI only builds + pushes — deploy is manual `docker compose pull && up -d` on the host.

## Secrets

| Secret | Location | Used By |
|--------|----------|---------|
| AWS access key / secret | `/opt/apps/eccensia/.env` (gitignored, template at `config/eccensia/.env.example`) | behemoth → SSM lookups |
| Binance API key / secret | SSM `behemoth.staging.binance.{apiKey,secret}` (`eu-west-1`) | behemoth at runtime |
| GHCR pull token | `docker login ghcr.io` (one-time on host, persists in `~/.docker/config.json`) | image pulls |
