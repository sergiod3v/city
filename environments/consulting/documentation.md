# Consulting Environment -- Infrastructure Documentation

## Purpose
Hosts AIejo Agency client automation stacks. Each client gets an isolated n8n instance on ECS Fargate Spot.

## Environments

| Env | Purpose | Cost |
|-----|---------|------|
| `staging` | Template development, new module testing | Minimal (Fargate Spot, idle) |
| `prod` | Live client instances | ~$0.01/hr per idle client |

## Architecture per Client

```
ECS Cluster (consulting-cluster)
└── ECS Service per client (Fargate Spot)
    └── n8n container (workflow engine)
    └── Redis container (WhatsApp context buffer -- 10-15s window)
RDS PostgreSQL (shared, per-schema isolation)
    └── schema per client + Row Level Security
AWS Secrets Manager
    └── {client_id}/whatsapp-credentials
    └── {client_id}/dian-api-key (Matias API)
    └── {client_id}/evolution-api-token
```

## Provisioning New Client
Single Terraform apply with client ID variable. No manual steps.

```bash
terraform apply -var="client_id=arasuper01" -var="client_name=Ara Supermarket"
```

This creates:
- ECS task definition + service for n8n
- Secrets Manager entries
- RDS schema + RLS policies
- IAM role scoped to that client's secrets

## WhatsApp Integration
Two provider options — decision is per-client based on risk tolerance:

| Provider | Cost | Risk |
|----------|------|------|
| Evolution API (self-hosted) | $0/msg | Number ban possible. Disclose risk before signing. |
| Meta Official API | $0.0002/utility msg | No ban risk, Meta-verified |

Default is NOT Evolution API. Each client gets a dedicated phone number to limit blast radius.

## Context Refiner Pattern (WhatsApp)
Users send 3-5 short messages instead of one. Flow:
1. Incoming webhooks buffered in Redis for 10-15 seconds
2. Claude Haiku consolidates fragments into one coherent prompt
3. Claude Sonnet processes consolidated prompt + generates reply

Reduces main Sonnet calls. Keeps conversation flow human-like.

## Secrets Access Pattern
ECS task role has `secretsmanager:GetSecretValue` scoped to `arn:aws:secretsmanager:us-east-1:*:secret:{client_id}/*`.
Each client task can only read its own secrets.

## DIAN Invoicing Module
- Provider: Matias API (375 COP per invoice)
- Flow: payment webhook → n8n → Matias API → PDF invoice → WhatsApp delivery
- Credentials stored per-client in Secrets Manager

## Terraform State
- Backend: S3 bucket `eccensia-tfstate-consulting-prod` (prod), `eccensia-tfstate-consulting-staging` (staging)
- Lock: DynamoDB table `eccensia-tfstate-lock` (shared with trading env)
- State key: `consulting/{client_id}/terraform.tfstate`

## Monthly Cost per Client (Idle Fargate Spot)
| Resource | Cost |
|----------|------|
| ECS Fargate Spot (n8n, idle) | ~$3-5 |
| Redis (ElastiCache t3.micro, shared) | ~$12 (amortized) |
| RDS schema (shared t3.medium) | ~$8 (amortized) |
| Secrets Manager | ~$0.40 |
| **Total per client** | **~$8-15** |

Margin: client pays 150k-600k COP/mo (~$37-150 USD). Infra cost per client <$15.

## Tagging Convention
```
Project     = aiego-agency
Environment = staging | prod
ClientId    = {client_id}
Owner       = alejocc
ManagedBy   = terraform
```

## Legal / Data Compliance
- Ley 1581/2012 (Colombia data protection): satisfied by per-client isolation (separate schema + RLS + scoped IAM)
- Each client's data never accessible by another client's ECS task
