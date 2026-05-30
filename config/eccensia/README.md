# Eccensia Stack — Hetzner Deploy

Host: Hetzner CPX11, Ubuntu 24.04. Deploy path: `/opt/apps/eccensia/`.

## Files

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | nginx + eccensia (Vite SPA) + behemoth (trading bot). |
| `nginx/conf.d/default.conf` | Reverse proxy. HTTP-only today; ACME path stubbed for future TLS. |
| `.env.example` | Template for AWS creds Behemoth uses to read SSM. Copy to `.env` on host. |

## First-Time Deploy

```bash
ssh hetzner
sudo mkdir -p /opt/apps/eccensia
sudo chown -R "$USER":"$USER" /opt/apps/eccensia
git clone git@github.com:sergiod3v/city.git ~/city   # if not already
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/

cd /opt/apps/eccensia
cp .env.example .env
$EDITOR .env                                          # paste real AWS creds

echo "$GHCR_PAT" | docker login ghcr.io -u sergiod3v --password-stdin
docker compose pull
docker compose up -d
docker compose ps
```

## Updates (after CI pushes new `:latest`)

```bash
cd /opt/apps/eccensia
docker compose pull <service>          # or omit for all
docker compose up -d <service>
docker compose ps
```

CI (`auto-trading`, `eccensia`) only builds + pushes to GHCR. The `pull` above is the deploy step — there is no watchtower.

## Config Changes

Edit files under `city/config/eccensia/` → commit → on host:

```bash
cd ~/city && git pull
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/ --exclude .env
cd /opt/apps/eccensia && docker compose up -d
```

## TLS (deferred)

`nginx/conf.d/default.conf` exposes the ACME webroot. To enable HTTPS later: add a `certbot` service (see git history pre-VPS-migration for the previous multi-domain config), issue certs, then add `listen 443 ssl;` blocks.
