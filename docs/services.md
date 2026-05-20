# ECCENSIA Service Map

Single EC2 `t3.micro` (`eu-west-1`, EIP `34.251.157.224`) hosts all services.
EC2 path: `/opt/eccensia/`
Compose file: `/opt/eccensia/docker-compose.yml`

## Service Table

| Service | Image | Tag | Internal Port | Domain | Volume | Network(s) |
|---------|-------|-----|--------------|--------|--------|------------|
| nginx | nginx:alpine | latest | 80/443 host | reverse proxy | conf, certs, webroot | net_proxy |
| certbot | certbot/certbot | latest | — | SSL renewal | certs, webroot | net_proxy |
| mercadillo-front | ghcr.io/sergiod3v/mercadillo | latest | 3000 | mercadillo.bijadillo.com | — | net_proxy, net_mercadillo |
| mercadillo-db | postgres:16-alpine | — | 5432 | internal only | postgres_data | net_mercadillo |
| eccensia | ghcr.io/sergiod3v/eccensia | latest | 80 | eccensia.com, www.eccensia.com, eccensia.sergiod3v.cloud | — | net_proxy |
| behemoth | ghcr.io/sergiod3v/auto-trading | latest | — | internal only (no HTTP) | behemoth_data | net_behemoth |

## Docker Networks

| Network | Members | Purpose |
|---------|---------|---------|
| net_proxy | nginx, certbot, mercadillo-front, eccensia | HTTP routing layer |
| net_mercadillo | mercadillo-front, mercadillo-db | DB isolated — only frontend can reach it |
| net_behemoth | behemoth | Fully isolated — no inbound HTTP, IAM via EC2 IMDS |

## SSL Certificates (Let's Encrypt via certbot)

| Domain | Cert Path | Notes |
|--------|-----------|-------|
| mercadillo.bijadillo.com | `/etc/letsencrypt/live/mercadillo.bijadillo.com/` | Active |
| eccensia.com | `/etc/letsencrypt/live/eccensia.com/` | DNS A → 34.251.157.224 required |
| www.eccensia.com | (same cert as eccensia.com, SAN) | |
| eccensia.sergiod3v.cloud | `/etc/letsencrypt/live/eccensia.sergiod3v.cloud/` | DNS A record needed |
| bijadillo.com | `/etc/letsencrypt/live/bijadillo.com/` | Stub — returns 503, cert issued for nginx startup |
| www.bijadillo.com | (same cert as bijadillo.com, SAN) | |

Renewal: certbot container loops `certbot renew` every 12h automatically.

## Build Pipelines

| Service | Repo | Workflow | Registry Path |
|---------|------|----------|--------------|
| mercadillo-front | sergiod3v/mercadillo | `.github/workflows/build-push.yml` | ghcr.io/sergiod3v/mercadillo:latest |
| eccensia | sergiod3v/eccensia | `.github/workflows/build-push.yml` | ghcr.io/sergiod3v/eccensia:latest |
| behemoth | sergiod3v/auto-trading | `.github/workflows/build-deploy.yml` | ghcr.io/sergiod3v/auto-trading:latest |

Trigger: push to `master` (each repo independently). GHCR auth: `GITHUB_TOKEN` (automatic in Actions).

## Secrets

| Secret | Location | Used By |
|--------|----------|---------|
| DB password | `/opt/eccensia/secrets/db_password.txt` | mercadillo-db (Docker secret) |
| AWS credentials | EC2 IAM instance profile (IMDSv2) | behemoth, mercadillo-front |
| Anthropic API key | SSM `/behemoth/staging/VITE_CLAUDE_API_KEY` | behemoth build-time arg |
| GHCR pull token | `docker login ghcr.io` (one-time on EC2) | all image pulls |
