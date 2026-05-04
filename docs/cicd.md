# CI/CD — GitHub Actions Terraform

Workflow file: `.github/workflows/terraform-staging.yml`

---

## Triggers

| Event | What runs | Condition |
|-------|-----------|-----------|
| Pull request to `master` | `terraform plan` → posts result as PR comment | Only if `environments/trading/staging/**` changed |
| Push to `master` | `terraform plan` then `terraform apply` | Only if `environments/trading/staging/**` changed |
| `workflow_dispatch` (manual) | `plan` or `apply` based on input | No path filter — always runs |

The path filter means: changing only docs or the workflow file itself does **not** trigger a plan or apply. Only real infra changes do.

---

## Steps (per run)

1. Checkout repo
2. Assume `behemoth-github-actions-terraform` IAM role via OIDC (15-min credentials, no stored keys)
3. Setup Terraform 1.6.x
4. `terraform fmt -check` — fails fast if formatting is off
5. `terraform init` — connects to S3 backend
6. `terraform validate` — catches HCL errors before planning
7. `terraform plan -out=tfplan` — always runs
8. On PR: post plan output as comment on the PR
9. On push to master / manual apply: `terraform apply -auto-approve tfplan`

---

## Auth Flow (OIDC)

```
GitHub Actions job starts
  → GitHub issues OIDC JWT for repo:sergiod3v/city
  → aws-actions/configure-aws-credentials exchanges JWT for temp IAM credentials
  → Credentials scoped to role behemoth-github-actions-terraform (15 min)
  → Terraform runs with those credentials
  → Credentials expire after job
```

No AWS access keys stored anywhere in GitHub. The role ARN is stored as secret `AWS_ROLE_ARN`.

---

## Manual Trigger (workflow_dispatch)

From GitHub UI:
1. github.com/sergiod3v/city → Actions → "Terraform — Trading Staging"
2. "Run workflow" → choose `plan` or `apply` → Run

From CLI:
```bash
# Plan only
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=plan

# Apply
gh workflow run "Terraform — Trading Staging" --repo sergiod3v/city --field action=apply

# Watch run
gh run list --repo sergiod3v/city --limit 5
gh run watch <run-id> --repo sergiod3v/city
```

---

## Normal Workflow for Infra Changes

```
1. Create branch: git checkout -b infra/change-description
2. Edit Terraform files in environments/trading/staging/
3. Push branch, open PR
4. GitHub Actions auto-runs plan, posts output as PR comment
5. Review plan in PR comment
6. Merge PR → apply runs automatically
7. Check Actions tab for apply output (EIP, RDS endpoint, etc.)
```

---

## Terraform State

- Backend: S3 `eccensia-tfstate-trading-staging`
- Key: `trading/staging/terraform.tfstate`
- Each apply writes updated state back to S3
- State is the source of truth — never edit manually

---

## If the workflow fails

Common causes:

| Error | Fix |
|-------|-----|
| `fmt check failed` | Run `terraform fmt -recursive` locally, push |
| `validate failed` | Fix HCL syntax, push |
| `Error: No valid credential sources` | OIDC provider or role trust policy issue — check IAM |
| `Error acquiring state lock` | No lock (no DynamoDB). If state is corrupted: download from S3, inspect, re-upload. |
| `UnauthorizedOperation` | IAM role missing a permission — check CloudTrail for the denied action |
