# Bijadillo Staging — Pre-Terraform Bootstrap

Shared EC2 platform for all Bijadillo web products. Same account as trading.

## Account
- Account ID: `670074751531`
- IAM user: `sergio-admin`
- Region: `eu-west-1`
- OIDC provider: reuse existing (same account)

---

## 1. S3 State Backend

Bucket: `bijadillo-tfstate-mercadillo-staging`

```bash
aws s3api create-bucket \
  --bucket bijadillo-tfstate-mercadillo-staging \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket bijadillo-tfstate-mercadillo-staging \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket bijadillo-tfstate-mercadillo-staging \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket bijadillo-tfstate-mercadillo-staging \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Note: State bucket stays in us-east-1 (same as trading convention). Infra deploys to eu-west-1.

---

## 2. SSM Parameters (create before terraform apply)

```bash
aws ssm put-parameter \
  --name "/mercadillo/staging/db/password" \
  --type "SecureString" \
  --value "CHANGE_ME_strong_password_here" \
  --region eu-west-1
```

---

## 3. Terraform Apply

```bash
cd environments/bijadillo/staging
terraform init
terraform plan
terraform apply
```

---

## 4. DNS Setup (at registrar, not AWS)

After `terraform apply`, get the EIP:

```bash
terraform output ec2_public_ip
```

At your domain registrar, create A records:
- `mercadillo.bijadillo.com` → `<EIP>`
- `bijadillo.com` → `<EIP>` (optional, for root domain)
- `*.bijadillo.com` → `<EIP>` (optional, wildcard for future products)

No Route 53 needed. See `ARCHITECTURE.md` for rationale.

---

## 5. EC2 Bootstrap

SSH in and deploy Docker Compose stack:

```bash
# SSH
ssh -i <key-path> ec2-user@$(terraform output -raw ec2_public_ip)

# Upload configs
scp -i <key-path> config/bijadillo/docker-compose.yml ec2-user@<ip>:/opt/bijadillo/
scp -i <key-path> -r config/bijadillo/nginx/ ec2-user@<ip>:/opt/bijadillo/

# Initial SSL cert (run AFTER DNS A record propagates)
cd /opt/bijadillo
docker compose up -d nginx  # must be running for ACME challenge
docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d mercadillo.bijadillo.com \
  --agree-tos --email sergioa.camachoc@gmail.com

# Restart nginx to pick up cert, start all services
docker compose up -d
```

---

## 6. GitHub Actions Secrets (Mercadillo repo)

| Secret | Source |
|---|---|
| `AWS_ROLE_ARN` | `terraform output deploy_role_arn` |
| `BIJADILLO_SG_ID` | `terraform output ec2_security_group_id` |
| `BIJADILLO_EC2_HOST` | `terraform output ec2_public_ip` |
| `SSH_PRIVATE_KEY` | Your Ed25519 private key |

---

## 7. Cost estimate (eu-west-1, no free tier)

| Resource | Cost/mo |
|---|---|
| EC2 t3.micro | ~$8.50 |
| S3 assets (<5GB) | ~$0.12 |
| CloudWatch/SSM | ~$0.30 |
| **Total (no RDS)** | **~$9/mo** |
| **+ RDS (when on)** | **+$15** |

Use on/off scripts to control EC2 and RDS independently.
