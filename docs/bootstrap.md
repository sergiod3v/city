# Bootstrap — Pre-Terraform Manual Setup

One-time steps done via AWS/GitHub CLI. Already complete — this is a record, not a to-do list.

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

Bucket: `eccensia-tfstate-trading-staging`

```bash
aws s3api create-bucket --bucket eccensia-tfstate-trading-staging --region us-east-1
aws s3api put-bucket-versioning --bucket eccensia-tfstate-trading-staging \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket eccensia-tfstate-trading-staging \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket eccensia-tfstate-trading-staging \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

No DynamoDB lock table. Solo dev, single pipeline.

---

## 2. SSM Parameters

All `SecureString`. Terraform does NOT manage these — fill manually.

| Parameter | Status |
|-----------|--------|
| `behemoth.staging.binance.apiKey` | Filled — Binance demo HMAC API key |
| `behemoth.staging.binance.secret` | Filled — Binance demo HMAC secret |
| `behemoth.staging.binance.privateKey` | Filled — Ed25519 private key (`~/.ssh/id_ed25519_binance_demo`) for prod |
| `behemoth.staging.slack.webhookUrl` | Placeholder |

To fill or update any:
```bash
aws ssm put-parameter --name "behemoth.staging.binance.apiKey" \
  --value "YOUR_VALUE" --type "SecureString" --overwrite --region us-east-1
```

Note: dot notation (`behemoth.staging.x`) — slash prefix (`/behemoth/staging/x`) breaks Windows Git Bash.

---

## 3. GitHub Actions OIDC

Allows GH Actions to assume IAM role without stored credentials. Credentials last 15 min per job.

```bash
# OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# IAM role
aws iam create-role \
  --role-name behemoth-github-actions-terraform \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy --role-name behemoth-github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam attach-role-policy --role-name behemoth-github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# GitHub secret
gh secret set AWS_ROLE_ARN --repo sergiod3v/city \
  --body "arn:aws:iam::670074751531:role/behemoth-github-actions-terraform"
```

Trust policy condition: `repo:sergiod3v/city:*`

---

## 4. GitHub Secrets (city repo)

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::670074751531:role/behemoth-github-actions-terraform` |
| `SSH_PUBLIC_KEY` | Content of `~/.ssh/id_ed25519_alejocc.pub` |
| `MY_IP_CIDR` | Your home IP as `/32` CIDR |

---

## 5. GitHub Secrets (auto-trading repo)

| Secret | Value |
|--------|-------|
| `EC2_HOST` | `52.73.213.253` |
| `SSH_PRIVATE_KEY` | Content of `~/.ssh/id_ed25519_alejocc` |

---

## 6. Binance Setup

- Demo API key type: **System-generated (HMAC)** — Ed25519 rejected by demo endpoint
- IP whitelist: `52.73.213.253` (the EIP — static, never changes unless you destroy and recreate it)
- Ed25519 keypair at `~/.ssh/id_ed25519_binance_demo` — generated for prod use only
- Public key PEM (for prod key creation when going live):
  ```
  -----BEGIN PUBLIC KEY-----
  MCowBQYDK2VwAyEAkdMzFu/NCzqHT4lf5Wu9Y4vgkRd6OmVzXAeuHoar9Og=
  -----END PUBLIC KEY-----
  ```
