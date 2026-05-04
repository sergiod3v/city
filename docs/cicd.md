# CI/CD — GitHub Actions Terraform

Workflow: `.github/workflows/terraform-staging.yml`

## Triggers

| Event | What runs | Condition |
|-------|-----------|-----------|
| PR to master | `terraform plan` → PR comment | `environments/trading/staging/**` changed |
| Push to master | `terraform plan` + `terraform apply` | `environments/trading/staging/**` changed |
| `workflow_dispatch` | plan or apply | Always runs |

## Steps

1. Checkout
2. Assume OIDC role (15-min credentials, no stored keys)
3. Setup Terraform 1.6.x
4. `terraform fmt -check`
5. `terraform init` → S3 backend
6. `terraform validate`
7. `terraform plan -out=tfplan`
8. On PR: post plan as comment
9. On push to master / manual apply: `terraform apply -auto-approve tfplan`

Job `timeout-minutes: 30`.

## Manual trigger

```bash
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=plan
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=apply
gh run list --repo sergiod3v/city --limit 5
```

## Git workflow (hard rule)

```
git checkout -b infra/your-change
# edit .tf files
terraform plan          # verify locally first
git push
gh pr create
# review plan comment → merge → apply runs
```

Never push infra changes directly to master.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `fmt check failed` | `terraform fmt -recursive`, push |
| Non-ASCII in description | Replace em dashes/special chars with hyphens |
| `No valid credential sources` | Check OIDC provider or role trust policy |
| Slow resource (RDS etc.) | 30-min timeout is set — shouldn't hit it without RDS |
