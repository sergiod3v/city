# Bijadillo Infrastructure — Architecture Decisions

Each section: what we chose, why, what we didn't choose, and when to revisit.

---

## Compute: EC2 t3.micro + Docker Compose

**Chosen.** One shared EC2 instance hosts all Bijadillo web products via Docker Compose + nginx reverse proxy.

**Why:**
- $8.50/mo total regardless of product count
- Full control: SSH access, local debugging, custom nginx config
- Proven pattern (Behemoth uses identical EC2+Docker setup)
- Supports SSR, API routes, WebSockets — no runtime limitations
- Adding a product = add container to compose + nginx server block

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **ECS Fargate** | ~$15-25/mo | No EC2 management, auto-scaling | More expensive at low traffic, no SSH, slower deploys, complex networking |
| **S3 + CloudFront (static)** | ~$0.50/mo | Cheapest, zero compute | Kills SSR/API routes — migration needed when server features arrive |
| **Lambda + API Gateway** | ~$0 at low traffic | True serverless, pay-per-request | Complex setup, cold starts, Next.js standalone not designed for Lambda, hard to debug |
| **Lightsail** | $3.50/mo | Cheaper than EC2 | Different AWS service, less Terraform support, limited instance profiles |
| **App Runner** | ~$5-15/mo | Container-native, auto-deploy from ECR | SaaS-like (conflicts with self-managed principle), limited config |

**Revisit when:** t3.micro runs out of memory (1 GiB) with multiple products → upgrade to t3.small ($17/mo). If sustained high traffic justifies auto-scaling → consider Fargate.

**Default recommendation:** EC2 t3.micro. Upgrade instance type before changing architecture.

---

## Reverse Proxy: nginx

**Chosen.** nginx in Docker container, routes by subdomain, terminates SSL.

**Alternatives:**

| Option | Pros | Cons |
|---|---|---|
| **Caddy** | Auto-SSL built-in (no certbot sidecar), simpler config | Less battle-tested at scale, less community knowledge |
| **Traefik** | Docker-native label routing, auto-discovery | Overkill for 2-3 services, heavier resource usage, complex config |
| **HAProxy** | Highest throughput | No built-in SSL management, config is verbose |
| **Direct (no proxy)** | Simplest | No subdomain routing, no SSL termination, only one app possible |

**Revisit when:** Managing certbot becomes annoying → switch to Caddy (auto-SSL). If running 10+ services with dynamic scaling → Traefik.

**Default recommendation:** nginx. Universal, lightweight, well-documented. Certbot sidecar handles SSL.

---

## SSL: Let's Encrypt + Certbot

**Chosen.** Certbot container auto-renews certs via ACME HTTP challenge. $0.

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **ACM + ALB** | ~$16/mo (ALB) | AWS-managed, auto-renewal, no cert management | ALB minimum cost kills budget. $16/mo just for load balancer with one target |
| **ACM + CloudFront** | ~$0 | Free cert + CDN | Only works for static/cacheable content in front of origin, adds complexity |
| **Caddy auto-SSL** | $0 | Built-in, zero config | Requires switching from nginx |
| **Self-signed** | $0 | Instant | Browser warnings, not production viable |

**Revisit when:** If Caddy is adopted → drop certbot entirely. If ALB becomes justified for other reasons (health checks, target groups) → use ACM.

**Default recommendation:** Let's Encrypt + certbot. Free, battle-tested, auto-renews.

---

## DNS: Registrar-managed (no Route 53)

**Chosen.** A records set manually at domain registrar. No AWS DNS.

**Why:**
- $0 vs $0.50/mo for Route 53 hosted zone
- EIP is static — DNS records rarely change
- One A record per subdomain, set once
- Registrar UI is fine for <10 records

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **Route 53** | $0.50/mo + queries | Terraform-managed, audit trail, API access | Overhead for 2-3 static A records, requires NS delegation at registrar |
| **Cloudflare DNS** | $0 | Free, fast propagation, DDoS proxy | External dependency, SaaS |

**Revisit when:** DNS changes become frequent (multiple environments, dynamic records, DKIM/SPF for email) → Route 53 makes Terraform-managed DNS worthwhile. Or if you need programmatic DNS for cert challenges (wildcard certs via DNS-01).

**Default recommendation:** Registrar DNS. Add Route 53 only when you need Terraform-managed records or >10 entries.

---

## Container Registry: GHCR (not ECR)

**Chosen.** GitHub Container Registry. Images at `ghcr.io/sergiod3v/<app>`.

**Why:**
- Free for public repos, generous free tier for private
- Auth via `GITHUB_TOKEN` — no additional credentials
- Same platform as code + CI/CD
- Proven with Behemoth

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **ECR** | ~$0.10/GB/mo + transfer | AWS-native, IAM-integrated, image scanning | Extra cost, separate auth setup, another AWS service to manage |
| **Docker Hub** | Free (1 private repo) | Universal | Rate limits on free tier, limited private repos |

**Revisit when:** Need AWS-native image scanning or cross-account access → ECR.

**Default recommendation:** GHCR. Simplest auth, free, already used.

---

## Database: RDS PostgreSQL db.t3.micro

**Chosen.** Managed PostgreSQL, EC2-only access (not publicly accessible).

**Why:**
- Relational data (orders, customers, products, merchants)
- Managed backups, point-in-time recovery, SSL enforcement
- On/off scripts for cost control (~$15/mo only when running)
- Same VPC as EC2 → security group restricts to EC2 only

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **SQLite on EC2** | $0 | Zero cost, zero management | Single-writer, no concurrent access, no managed backups, dies with instance |
| **Aurora Serverless v2** | ~$50+/mo minimum | Auto-scaling, serverless | Way too expensive for prototype traffic |
| **Supabase/Neon** | Free tier | Managed Postgres, free tier generous | SaaS dependency, vendor lock-in |
| **Self-hosted Postgres on EC2** | $0 (shared instance) | No RDS cost | No managed backups, competes for EC2 memory, manual upgrades |

**Revisit when:** If RDS cost is unjustified pre-revenue → self-hosted Postgres on EC2 or SQLite. If traffic spikes → Aurora Serverless.

**Default recommendation:** RDS for anything with real users. SQLite for prototyping/dev only.

---

## Secrets: SSM Parameter Store SecureString

**Chosen.** Free. Encrypted with `aws/ssm` managed key.

**Alternatives:**

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **Secrets Manager** | $0.40/secret/mo | Auto-rotation, cross-account, richer API | Costs money for identical functionality at this scale |
| **GitHub Actions secrets** | $0 | Simple, CI-native | Not accessible from EC2 at runtime, not Terraform-managed |
| **Vault** | Self-hosted cost | Enterprise-grade, dynamic secrets | Massive overhead for solo dev |

**Default recommendation:** SSM. Free, sufficient, Terraform-native.

---

## CI/CD Auth: OIDC (not static keys)

**Chosen.** GitHub Actions OIDC → AWS IAM role assumption. No stored credentials.

**Why:**
- No long-lived AWS keys in GitHub secrets
- Role scoped to specific repo (`sergiod3v/mercadillo`)
- Automatic credential rotation (each job gets temporary session)
- Consistent with city repo pattern

**Alternatives:**

| Option | Pros | Cons |
|---|---|---|
| **Static IAM keys** | Simpler setup | Long-lived credentials, rotation burden, blast radius if leaked |
| **GitHub App** | Fine-grained permissions | Overkill, complex setup |

**Default recommendation:** OIDC. Always. Static keys only as last resort.

---

## Multi-App: Shared EC2 (not per-product)

**Chosen.** All Bijadillo web products share one EC2 instance.

**Why:**
- Same security posture (public web, same domain family)
- Same owner, same lifecycle
- Docker Compose handles multi-container orchestration
- $8.50 total, not $8.50 × N

**Behemoth stays separate because:**
- Different security (private trading bot vs public web)
- Different network (SSH-only, no HTTP)
- Different lifecycle (24/7 market hours vs on-demand)

**Revisit when:** Products have conflicting resource needs, uptime requirements, or security profiles.

---

## CDN: None (CloudFront later)

**Chosen.** EC2 serves traffic directly. No CDN.

**Why:**
- Low traffic prototype — CDN adds complexity for zero benefit
- EC2 in eu-west-1 is close enough to Colombia (~120ms)
- Static assets cached by browser (Next.js `/_next/static/` is immutable)

**When to add CloudFront:**
- Sustained traffic where edge caching measurably helps
- Need for geographic distribution (users outside LatAm/EU)
- DDoS protection becomes a concern

CloudFront in front of EC2 (origin = EIP) is a pure additive change — no architecture changes needed. Cache `/_next/static/*`, pass dynamic requests through.

**Default recommendation:** Skip until you have traffic metrics justifying it.

---

## State Backend: S3 only (no DynamoDB lock)

**Chosen.** Solo dev, single pipeline, no concurrent applies.

**Revisit when:** Multiple developers or concurrent CI pipelines → add DynamoDB lock table.

---

## VPC: Default (no custom)

**Chosen.** Default VPC in eu-west-1. No custom VPC per environment.

**Why:** Custom VPCs add NAT gateway costs (~$32/mo), subnet management, and routing complexity. Unjustifiable for solo dev.

**Revisit when:** Compliance requires network isolation, or multiple environments need separate blast radii.
