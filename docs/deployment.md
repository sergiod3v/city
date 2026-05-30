# Deployment Runbook

Host: Hetzner CPX11 (`ssh hetzner`). Deploy path: `/opt/apps/eccensia/`.

Source of truth: `city/config/eccensia/` (compose, nginx, `.env.example`).

## First-Deploy Bootstrap

```bash
ssh hetzner

sudo mkdir -p /opt/apps/eccensia
sudo chown -R "$USER":"$USER" /opt/apps/eccensia
git clone git@github.com:sergiod3v/city.git ~/city || (cd ~/city && git pull)
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/

cd /opt/apps/eccensia
cp .env.example .env
$EDITOR .env                                              # paste AWS_ACCESS_KEY_ID / SECRET

echo "$GHCR_PAT" | docker login ghcr.io -u sergiod3v --password-stdin
docker compose pull
docker compose up -d
docker compose ps
```

## Per-Service Updates

```bash
ssh hetzner
cd /opt/apps/eccensia

docker compose pull behemoth && docker compose up -d behemoth
docker compose pull eccensia && docker compose up -d eccensia
docker compose pull nginx    && docker compose up -d nginx
```

CI builds + pushes `:latest` to GHCR. There is no watchtower / auto-pull — the commands above are the deploy step.

## Config Changes (compose, nginx)

```bash
# Local
$EDITOR city/config/eccensia/...
git commit -m "..." && git push

# Host
ssh hetzner
cd ~/city && git pull
rsync -a ~/city/config/eccensia/ /opt/apps/eccensia/ --exclude .env
cd /opt/apps/eccensia && docker compose up -d
```

## Rollback

```bash
cd /opt/apps/eccensia
# GHCR keeps SHA-tagged images. Pin the previous SHA in docker-compose.yml:
#   image: ghcr.io/sergiod3v/<svc>:<short-sha>
docker compose pull <svc>
docker compose up -d <svc>
```

## Verification

```bash
docker compose ps                          # all Up
docker network ls | grep -E "net_proxy|net_behemoth"
curl -I http://eccensia.com                # 200 (HTTP only — TLS deferred)
docker compose logs behemoth --tail 30     # SSM params loaded, trading loop running
```

## TLS (deferred)

nginx serves HTTP only today. ACME webroot path is reserved in `nginx/conf.d/default.conf`. To enable HTTPS:

1. Add `certbot` service to `docker-compose.yml` (mount `./nginx/certs` + `./nginx/webroot`).
2. `docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d eccensia.com -d www.eccensia.com --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email`.
3. Add `listen 443 ssl;` server block referencing `/etc/letsencrypt/live/eccensia.com/`.
4. `docker compose exec nginx nginx -s reload`.

## AWS Lifecycle

No longer applicable — the EC2 backing Behemoth was destroyed in commit `6924ea1` (`chore(trading): remove all EC2/CW/IAM resources for VPS migration`). Behemoth's AWS surface is now SSM read-only via the IAM user creds in `/opt/apps/eccensia/.env`.
