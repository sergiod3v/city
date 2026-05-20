# City — Infrastructure Monorepo

## What This Is
Terraform repo for all ECCENSIA infrastructure. Single source of truth for infra state.

## Business Lines
- `environments/trading/` — Behemoth trading bot (EC2 + Docker + RDS)
- `environments/bijadillo/` — Bijadillo web platform (shared EC2 + Docker Compose + nginx + RDS)
- `environments/consulting/` — AIejo Agency client stacks (ECS Fargate, n8n per client) — parked

## Hard Rules
- Never push infra changes directly to master. Branch → PR → plan passes → merge → apply.
- Never use local Terraform state. Always S3 backend.
- Never commit `.tfvars` with real values. `.tfvars.example` only.
- Never commit `.terraform/` directories.
- No secrets in code or env vars. Use SSM Parameter Store SecureString.
- Tag every resource: Project, Environment, Owner, ManagedBy=terraform.
- Never EKS. ECS Fargate only for containers.

## Key Decisions (already made, don't revisit)
- **VPC**: Use default VPC — no custom VPC per environment. Too much overhead for a solo project.
- **State lock**: S3 only, no DynamoDB — solo dev, single pipeline, no concurrent applies.
- **Secrets**: SSM Parameter Store SecureString (free) — not Secrets Manager ($0.40/secret/mo).
- **Instances**: On-demand only — no reserved instances, no upfront commitment.
- **Encryption**: AWS-managed keys only (aws/ebs, aws/rds, aws/ssm) — cannot be lost or deleted by you.
- **Deployment**: Docker on EC2. Bot runs as a container pulled from GHCR.

## AWS Account
- Account: `670074751531`
- Region: `eu-west-1`
- IAM user: `sergio-admin`
- OIDC role for GitHub Actions: `behemoth-github-actions-terraform`

## Active Environments
- `environments/trading/staging/` — active, Terraform written, CI/CD wired
- `environments/bijadillo/staging/` — scaffolded, not yet applied. Shared EC2 for all Bijadillo products (Mercadillo first). See BOOTSTRAP.md

## Costs (no free tier — account is old)
- Trading EC2 t3.micro: ~$8.50/mo
- Bijadillo EC2 t3.micro: ~$8.50/mo
- RDS db.t3.micro (per instance): ~$15/mo
- S3 state, SSM, CloudWatch: ~$1/mo
- **Total staging (both running, no RDS): ~$18/mo**
- **Total staging (both running + RDS): ~$33/mo**

## CI/CD
- Plan: triggered on PR touching `environments/{trading,bijadillo}/staging/**`
- Apply: triggered on merge to master or manual workflow_dispatch
- Auth: OIDC, no stored AWS keys
- See: `docs/cicd.md`
