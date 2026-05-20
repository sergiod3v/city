# Deployment Runbook

EC2: `i-083ca0f5a61cf32b8`, EIP `34.251.157.224`, `eu-west-1`
SSH: `ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@34.251.157.224`

## First-Deploy Bootstrap (EC2 already running)

```bash
ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@34.251.157.224

# GHCR login (one-time — survives reboots via ~/.docker/config.json)
docker login ghcr.io -u sergiod3v -p <GITHUB_PAT>

# Create secrets dir + DB password (never committed)
mkdir -p /opt/eccensia/secrets
echo "your-strong-db-password" > /opt/eccensia/secrets/db_password.txt
chmod 600 /opt/eccensia/secrets/db_password.txt

# Copy compose config from city repo (or clone city and symlink)
# config/eccensia/ → /opt/eccensia/

# Start all services
cd /opt/eccensia
docker compose up -d
docker compose ps
```

## SSL Bootstrap (one-time per domain)

HTTP block must be live before issuing. Run after `docker compose up -d`.

```bash
# Issue certs — repeat for each domain
docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d mercadillo.bijadillo.com \
  --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email

docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d eccensia.com -d www.eccensia.com \
  --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email

docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d eccensia.sergiod3v.cloud \
  --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email

docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d bijadillo.com -d www.bijadillo.com \
  --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email

# Reload nginx after certs issued
docker compose exec nginx nginx -s reload
```

DNS A records required before issuing:
- `eccensia.com` + `www.eccensia.com` → `34.251.157.224`
- `eccensia.sergiod3v.cloud` → `34.251.157.224`

## Per-Service Updates

```bash
cd /opt/eccensia

# Pull new image + restart single service
docker compose pull <service>
docker compose up -d <service>

# Examples
docker compose pull behemoth && docker compose up -d behemoth
docker compose pull mercadillo-front && docker compose up -d mercadillo-front
docker compose pull eccensia && docker compose up -d eccensia
```

## Rollback

```bash
cd /opt/eccensia

# Roll back to previous image (GHCR keeps last 3 tags)
docker compose pull ghcr.io/sergiod3v/<service>:<previous-sha>
# Edit docker-compose.yml image tag to pin SHA, then:
docker compose up -d <service>
```

## Verification

```bash
docker compose ps                          # all services Up
docker network ls                          # net_proxy, net_mercadillo, net_behemoth present
curl -I https://mercadillo.bijadillo.com   # 200
curl -I https://eccensia.com               # 200
curl -I https://eccensia.sergiod3v.cloud   # 200 (after DNS)
curl -I https://bijadillo.com              # 503 (stub)
docker compose logs behemoth --tail 20     # SSM params loaded, trading loop running
docker compose exec mercadillo-front ping mercadillo-db   # reachable
docker compose exec behemoth ping mercadillo-front        # should fail (isolated) ✓
```

## EC2 Start/Stop

```bash
# From city repo root (Bash required — uses AWS CLI)
./infra.sh up
./infra.sh down
./infra.sh status
```

EIP `34.251.157.224` is always retained (EIP charge ~$0.005/hr while stopped). Binance API whitelist stays valid.
