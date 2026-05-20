# ECCENSIA Infra Control

Single EC2 (eu-west-1, EIP `34.251.157.224`) running all services via Docker Compose at `/opt/eccensia/`.

## Prerequisites

Aliases live in `~/.bashrc`. Source after changes: `source ~/.bashrc`

---

## EC2 Lifecycle

| Command | Action |
|---------|--------|
| `ec2-up` | Start EC2, wait until running, print IP |
| `ec2-down` | Stop EC2 (EIP + Binance whitelist preserved) |
| `ec2-status` | Show state, EIP, launch time, service list |

Cost: ~$0.012/hr running · ~$0.005/hr stopped (EIP charge only)

Backed by `city/infra.sh` — resolves instance via tag `Name=behemoth-staging-bot`, no hardcoded ID.

---

## SSH

```bash
ssh eccensia          # via ~/.ssh/config alias
ec2-ssh               # same, bashrc alias
```

Config (`~/.ssh/config`):
```
Host eccensia
    HostName 34.251.157.224
    User ec2-user
    IdentityFile ~/.ssh/id_ed25519_alejocc
    IdentitiesOnly yes
```

---

## Service Control (independent of EC2 lifecycle)

All commands run `docker compose` on EC2 at `/opt/eccensia/`.

### Generic functions

```bash
svc-up <service>              # docker compose up -d <service>
svc-down <service>            # docker compose stop <service>
svc-restart <service>         # docker compose restart <service>
svc-pull <service>            # pull latest image + redeploy
svc-logs <service> [lines]    # follow logs (default: last 50 lines)
svc-status                    # docker compose ps
```

### Per-service quick aliases

| Alias | Equivalent |
|-------|-----------|
| `behemoth-restart` | `svc-restart behemoth` |
| `behemoth-logs` | `svc-logs behemoth` |
| `eccensia-restart` | `svc-restart eccensia` |
| `eccensia-logs` | `svc-logs eccensia` |
| `mercadillo-restart` | `svc-restart mercadillo-front` |
| `mercadillo-logs` | `svc-logs mercadillo-front` |
| `nginx-restart` | `svc-restart nginx` |
| `nginx-logs` | `svc-logs nginx` |

### Services

| Name | Description | Port |
|------|-------------|------|
| `behemoth` | Trading bot | — |
| `eccensia` | Vite SPA | :80 (via nginx) |
| `mercadillo-front` | Next.js storefront | :3000 (via nginx) |
| `mercadillo-db` | PostgreSQL | :5432 |
| `nginx` | Reverse proxy + SSL termination | :80/:443 |

---

## First-Deploy Bootstrap (one-time)

```bash
ssh eccensia

# Create secrets
sudo mkdir -p /opt/eccensia/secrets
echo "your_db_password" | sudo tee /opt/eccensia/secrets/db_password.txt
sudo chmod 600 /opt/eccensia/secrets/db_password.txt

# Copy compose config from city repo
scp -r city/config/eccensia/ ec2-user@34.251.157.224:/opt/eccensia/

# Authenticate to GHCR
echo $GHCR_PAT | docker login ghcr.io -u sergiod3v --password-stdin

# Start all services
cd /opt/eccensia && docker compose up -d
```

---

## SSL (certbot, one-time per domain)

```bash
svc-up certbot  # or run manually:
ssh eccensia "docker compose -f /opt/eccensia/docker-compose.yml run --rm certbot \
  certonly --webroot --webroot-path=/var/www/certbot \
  -d eccensia.com -d www.eccensia.com \
  -d eccensia.sergiod3v.cloud \
  -d mercadillo.bijadillo.com -d bijadillo.com \
  --email sergioa.camachoc@gmail.com --agree-tos --no-eff-email"
```

DNS A records required before issuance:
- `eccensia.com` + `www` → `34.251.157.224`
- `eccensia.sergiod3v.cloud` → `34.251.157.224`

---

## Git / Infra Change Policy

- **Never push to master directly.** Branch → PR → plan passes → merge → apply.
- Never commit `.tfvars` with real values (use `.tfvars.example`).
- Never commit `.terraform/` directories.
- State backend: S3 (never local).
- Tag every resource: `Project`, `Environment`, `Owner`, `ManagedBy=terraform`.
