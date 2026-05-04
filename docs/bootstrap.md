# Bootstrap — Pre-Terraform Manual Setup

These steps were run once via AWS CLI and GitHub CLI. They cannot be managed by Terraform.
**Do not run these again** — they already exist. This doc is a record of what was done and why.

---

## AWS Account

| Field | Value |
|-------|-------|
| Account ID | `670074751531` |
| IAM user | `sergio-admin` |
| Region | `us-east-1` |
| SSH key | `id_ed25519_alejocc` (Ed25519) |

---

## 1. S3 State Backend

**Bucket:** `eccensia-tfstate-trading-staging`

```bash
aws s3api create-bucket \
  --bucket eccensia-tfstate-trading-staging \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket eccensia-tfstate-trading-staging \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket eccensia-tfstate-trading-staging \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket eccensia-tfstate-trading-staging \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Why no DynamoDB lock table: solo dev, single GitHub Actions pipeline, no concurrent applies possible.

---

## 2. SSM Parameter Placeholders

Four `SecureString` parameters created with `PLACEHOLDER` values.
Terraform manages `behemoth.staging.db.password` (auto-overwrites with generated password on apply).
The other three must be filled manually after first `terraform apply`.

```bash
aws ssm put-parameter --name "behemoth.staging.binance.apiKey" \
  --value "PLACEHOLDER" --type "SecureString" --region us-east-1

aws ssm put-parameter --name "behemoth.staging.binance.secret" \
  --value "PLACEHOLDER" --type "SecureString" --region us-east-1

aws ssm put-parameter --name "behemoth.staging.slack.webhookUrl" \
  --value "PLACEHOLDER" --type "SecureString" --region us-east-1

aws ssm put-parameter --name "behemoth.staging.db.password" \
  --value "PLACEHOLDER" --type "SecureString" --region us-east-1
```

Note on naming: SSM hierarchy paths (`/foo/bar`) fail in Windows Git Bash due to leading-slash
interpretation. Dot notation (`foo.bar.baz`) works on all platforms and is used throughout.

---

## 3. GitHub Actions OIDC

Allows GitHub Actions to assume an IAM role without storing long-lived credentials anywhere.
Credentials last 15 minutes per job run.

### OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

ARN: `arn:aws:iam::670074751531:oidc-provider/token.actions.githubusercontent.com`

### IAM Role

Role: `behemoth-github-actions-terraform`
ARN: `arn:aws:iam::670074751531:role/behemoth-github-actions-terraform`

Trust policy allows any ref in `sergiod3v/city` to assume this role:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::670074751531:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:sergiod3v/city:*"
      }
    }
  }]
}
```

Attached policies:
- `arn:aws:iam::aws:policy/PowerUserAccess`
- `arn:aws:iam::aws:policy/IAMFullAccess` (needed for Terraform to create IAM roles/profiles)

### GitHub Secret

```bash
gh secret set AWS_ROLE_ARN \
  --repo sergiod3v/city \
  --body "arn:aws:iam::670074751531:role/behemoth-github-actions-terraform"
```

---

## 4. After First terraform apply

Once `terraform apply` runs via GitHub Actions, do these:

```bash
# Get the EIP from apply output, then whitelist it on Binance:
# binance.com → API Management → your demo key → Edit → IP Whitelist

# Fill Binance demo API keys:
aws ssm put-parameter --name "behemoth.staging.binance.apiKey" \
  --value "YOUR_BINANCE_DEMO_APIKEY" --type "SecureString" --overwrite --region us-east-1

aws ssm put-parameter --name "behemoth.staging.binance.secret" \
  --value "YOUR_BINANCE_DEMO_SECRET" --type "SecureString" --overwrite --region us-east-1

# Fill Slack webhook:
aws ssm put-parameter --name "behemoth.staging.slack.webhookUrl" \
  --value "https://hooks.slack.com/services/..." --type "SecureString" --overwrite --region us-east-1
```

Then SSH into EC2, clone auto-trading repo, start the bot.
