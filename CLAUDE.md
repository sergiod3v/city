# City -- Infrastructure Monorepo

## What This Is
Central Terraform repository for all ECCENSIA infrastructure.
Every environment Alejo spins up for any project lives here.
This is the single source of truth for infrastructure state.

## Business Lines
- `environments/trading/` -- Behemoth trading bot infra (EC2, RDS, monitoring)
- `environments/consulting/` -- AIejo Agency client stacks (ECS Fargate, n8n per client, RDS)
- `shared/` -- Resources shared across all environments (networking, IAM roles, S3 state buckets)

## Hard Rules
- Every environment has its own S3 backend for Terraform state. Never use local state.
- State buckets: `eccensia-tfstate-{environment}` (e.g. eccensia-tfstate-trading-prod)
- Never commit .tfvars files containing real values. Use .tfvars.example as template.
- Never commit .terraform/ directories.
- All secrets go into AWS Secrets Manager, referenced by ARN -- never hardcoded.
- Tag every resource: Project, Environment, Owner, ManagedBy=terraform

## Stack
- IaC: Terraform >= 1.6
- Cloud: AWS (primary)
- Never use CloudFormation. Never suggest EKS -- use ECS Fargate.
- Remote state: S3 + DynamoDB lock table

## Module Usage
All environments consume from `modules/`. Never copy-paste Terraform between environments.
If you need a new pattern: create a module in `modules/`, then call it.

## AWS Account Strategy
Single AWS account. Logical separation via:
- VPCs per business line (trading VPC, consulting VPC)
- IAM roles with least privilege per service
- Resource tags for cost allocation
- S3 state buckets per environment

## Environments
- staging: for testing infra changes before prod. Low-cost instances.
- prod: live infrastructure. Reserved instances where applicable.
