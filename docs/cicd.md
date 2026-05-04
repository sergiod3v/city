# CI/CD — GitHub Actions Terraform

Workflow: `.github/workflows/terraform-staging.yml`

## Triggers

| Event | What runs | Condition |
|-------|-----------|-----------|
| PR to master | `terraform plan` → PR comment | `environments/trading/staging/**` changed |
| Push to master | `terraform plan` then `terraform apply` | `environments/trading/staging/**` changed |
| `workflow_dispatch` | plan or apply (your choice) | Always runs |

## Steps

1. Checkout
2. Assume `behemoth-github-actions-terraform` via OIDC (15-min credentials)
3. Setup Terraform 1.6.x
4. `terraform fmt -check`
5. `terraform init` → S3 backend
6. `terraform validate`
7. `terraform plan -out=tfplan`
8. On PR: post plan as comment
9. On push to master / manual apply: `terraform apply -auto-approve tfplan`

Job timeout: 30 minutes.

## Manual trigger

```bash
# Plan only
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=plan

# Apply
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=apply

# Watch
gh run list --repo sergiod3v/city --limit 5
gh run watch <run-id> --repo sergiod3v/city
```

## Git workflow (hard rule)

```
git checkout -b infra/your-change
# make changes
terraform plan   # verify locally first
git push
gh pr create
# review plan comment on PR
# merge → apply runs automatically
```

Never push infra changes directly to master.

## Variables injected by workflow

| Env var | Value | Source |
|---------|-------|--------|
| `TF_VAR_env` | `staging` | Hardcoded in workflow |
| `TF_VAR_project` | `auto-trading` | Hardcoded in workflow |
| `TF_VAR_client` | `myself` | Hardcoded in workflow |
| `TF_VAR_ssh_public_key` | Key content | Secret `SSH_PUBLIC_KEY` |
| `TF_VAR_your_ip_cidr` | Your IP | Secret `MY_IP_CIDR` |

## Troubleshooting

| Error | Fix |
|-------|-----|
| `fmt check failed` | `terraform fmt -recursive` locally, push |
| `InvalidParameterValue` non-ASCII in description | Replace em dashes with hyphens in .tf files |
| `No valid credential sources` | Check OIDC provider or role trust policy |
| Plan shows unexpected destroy | Read plan carefully before merging — never auto-approve surprises |
