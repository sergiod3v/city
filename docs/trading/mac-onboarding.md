# Mac Onboarding — New Machine Setup

Everything needed to work with the city repo and the Behemoth stack from a fresh Mac.

---

## 1. Prerequisites

```bash
# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core tools
brew install awscli terraform gh git

# Python (for boto3/Behemoth bot)
brew install python@3.11

# Node (for MCP servers + PM2)
brew install node

# PM2 (global)
npm install -g pm2
```

---

## 2. SSH Key

The Ed25519 key `id_ed25519_alejocc` is used for:
- SSH into EC2 instances
- GitHub pushes (sergiod3v account)

Copy the key from your secure backup (1Password / external drive) to `~/.ssh/`:
```bash
# Should already exist if copied from backup
ls ~/.ssh/id_ed25519_alejocc
ls ~/.ssh/id_ed25519_alejocc.pub
```

Set permissions:
```bash
chmod 600 ~/.ssh/id_ed25519_alejocc
chmod 644 ~/.ssh/id_ed25519_alejocc.pub
```

Configure `~/.ssh/config`:
```
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_alejocc
  IdentitiesOnly yes
```

---

## 3. AWS CLI

```bash
aws configure
# AWS Access Key ID: <sergio-admin access key>
# AWS Secret Access Key: <sergio-admin secret>
# Default region: us-east-1
# Default output format: yaml
```

Verify:
```bash
aws sts get-caller-identity
# Should show: Account: 670074751531, UserId: AIDAZYA4RJIVXW3LBB3GH
```

---

## 4. GitHub CLI

```bash
gh auth login
# Select: GitHub.com
# Protocol: SSH
# SSH key: ~/.ssh/id_ed25519_alejocc.pub
# Auth method: Paste an authentication token
# Token: <sergiod3v PAT>
```

Verify:
```bash
gh auth status
# Should show: Logged in as sergiod3v
```

---

## 5. Clone Repos

```bash
git clone git@github.com:sergiod3v/city.git
git clone git@github.com:sergiod3v/auto-trading.git
```

---

## 6. Terraform Init (city repo)

**Do not run terraform apply locally.** Applies run via GitHub Actions only.
But you can plan locally to test changes before pushing.

```bash
cd city/environments/trading/staging
terraform init    # pulls providers, connects to S3 backend
terraform plan    # safe read-only check
```

---

## 7. Claude Code + MCP Servers

Install Claude Code:
```bash
npm install -g @anthropic-ai/claude-code
```

MCP servers (install globally):
```bash
npm install -g @modelcontextprotocol/server-github
npm install -g @modelcontextprotocol/server-postgres
```

Configure `~/.claude/settings.json` — copy the `mcpServers` block from this machine's settings file.
Required values to fill:
- `GITHUB_PERSONAL_ACCESS_TOKEN` — your sergiod3v PAT
- Postgres connection string — available after `terraform apply` (get RDS endpoint from outputs)

AWS docs and Context7 MCPs use `uvx` and `npx` respectively — no install needed, they self-fetch.

---

## 8. Verify Everything

```bash
# AWS
aws s3 ls s3://eccensia-tfstate-trading-staging

# GitHub
gh repo view sergiod3v/city

# Terraform
cd city/environments/trading/staging && terraform plan

# SSM params (should all exist, most are PLACEHOLDER until apply)
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=behemoth.staging" \
  --query "Parameters[].Name" --output yaml --region us-east-1
```

---

## 9. After terraform apply (first time)

Once the first apply runs via GitHub Actions:
1. Get EIP from Actions output → whitelist on Binance demo API key
2. Fill Binance + Slack SSM params (see `docs/bootstrap.md` → Step 4)
3. SSH into EC2:
   ```bash
   ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@<EIP>
   ```
4. Clone auto-trading, install requirements, start PM2
