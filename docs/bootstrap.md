# Bootstrap — Pre-Terraform Manual Setup

One-time steps done via AWS/GitHub CLI. Already complete — this is a record, not a to-do list.

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

No DynamoDB lock. Solo dev, single pipeline.

---

## 2. SSM Parameters

All `SecureString`. Fill manually after `terraform apply`.

| Parameter | Status |
|-----------|--------|
| `behemoth.staging.binance.apiKey` | Filled |
| `behemoth.staging.binance.secret` | Filled |
| `behemoth.staging.binance.privateKey` | Filled (Ed25519 for prod) |
| `behemoth.staging.slack.webhookUrl` | Placeholder |

```bash
aws ssm put-parameter --name "behemoth.staging.binance.apiKey" \
  --value "YOUR_VALUE" --type "SecureString" --overwrite --region us-east-1
```

Dot notation — slash prefix breaks Windows Git Bash.

---

## 3. GitHub Actions OIDC

```bash
# OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# IAM role (trust policy: repo:sergiod3v/city:*)
aws iam create-role \
  --role-name behemoth-github-actions-terraform \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy --role-name behemoth-github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam attach-role-policy --role-name behemoth-github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

---

## 4. GitHub Secrets (city repo)

| Secret | What |
|--------|------|
| `AWS_ROLE_ARN` | ARN of `behemoth-github-actions-terraform` role |
| `SSH_PUBLIC_KEY` | Content of `~/.ssh/id_ed25519_alejocc.pub` |
| `MY_IP_CIDR` | Your home IP as `/32` CIDR |

---

## 5. GitHub Secrets (auto-trading repo)

| Secret | What |
|--------|------|
| `EC2_HOST` | EC2 elastic IP (from `terraform output ec2_elastic_ip`) |
| `SSH_PRIVATE_KEY` | Content of `~/.ssh/id_ed25519_alejocc` |

---

## 6. Binance Setup

- Demo key type: **System-generated (HMAC)** — Ed25519 rejected by demo endpoint
- IP whitelist: your EC2 EIP (from `terraform output ec2_elastic_ip`)
- Ed25519 keypair at `~/.ssh/id_ed25519_binance_demo` — for prod only
- Ed25519 PEM public key (paste into Binance when creating prod key):
  ```
  -----BEGIN PUBLIC KEY-----
  MCowBQYDK2VwAyEAkdMzFu/NCzqHT4lf5Wu9Y4vgkRd6OmVzXAeuHoar9Og=
  -----END PUBLIC KEY-----
  ```
