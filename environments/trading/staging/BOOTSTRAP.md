# Staging Bootstrap — Pre-Terraform Resources

These resources were created manually via AWS CLI **before** `terraform init`.
They cannot be managed by Terraform (chicken-and-egg: Terraform needs them to run).
Do NOT import them into Terraform state — leave them as external dependencies.

## Account
- Account ID: `670074751531`
- IAM user: `sergio-admin`
- Region: `us-east-1`

---

## 1. S3 State Backend

Bucket: `eccensia-tfstate-trading-staging`

Created with:
```bash
aws s3api create-bucket --bucket eccensia-tfstate-trading-staging --region us-east-1
aws s3api put-bucket-versioning --bucket eccensia-tfstate-trading-staging \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket eccensia-tfstate-trading-staging \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket eccensia-tfstate-trading-staging \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

No DynamoDB lock table — solo dev, no concurrent applies.

---

## 2. SSM Parameters (empty placeholders)

All created as `SecureString` (encrypted with default KMS key, free).
Terraform manages only `behemoth.staging.db.password` (auto-generated password).
You must fill the other three after `terraform apply`.

| Parameter | Status | Who fills it |
|-----------|--------|-------------|
| `behemoth.staging.binance.apiKey` | PLACEHOLDER | You — after getting Binance demo keys |
| `behemoth.staging.binance.secret` | PLACEHOLDER | You — after getting Binance demo keys |
| `behemoth.staging.slack.webhookUrl` | PLACEHOLDER | You — Slack app webhook URL |
| `behemoth.staging.db.password` | Auto | Terraform (random_password + aws_ssm_parameter) |

Created with:
```bash
aws ssm put-parameter --name "behemoth.staging.binance.apiKey" --value "PLACEHOLDER" --type "SecureString" --region us-east-1
aws ssm put-parameter --name "behemoth.staging.binance.secret" --value "PLACEHOLDER" --type "SecureString" --region us-east-1
aws ssm put-parameter --name "behemoth.staging.slack.webhookUrl" --value "PLACEHOLDER" --type "SecureString" --region us-east-1
aws ssm put-parameter --name "behemoth.staging.db.password" --value "PLACEHOLDER" --type "SecureString" --region us-east-1
```

---

## 3. First-Time Setup Order

```
1. aws configure (region us-east-1)          ← done
2. Create S3 bucket (above)                  ← done
3. Create SSM placeholders (above)           ← done
4. terraform init                            ← next
5. terraform plan
6. terraform apply
7. Fill Binance + Slack SSM params with real values
8. ssh into EC2, deploy bot, pm2 start
```

---

## Cost Summary (staging)

| Resource | Cost |
|----------|------|
| S3 backend bucket | ~$0 (few KB state) |
| SSM Standard SecureString x4 | $0 (free tier) |
| EC2 t3.micro | $0 (free tier 750hr/mo yr1) |
| RDS db.t3.micro | $0 (free tier 750hr/mo yr1) |
| CloudWatch logs | $0 (under 5GB/mo free) |
| EIP (attached) | $0 |
| **Total staging** | **$0 during free tier** |
