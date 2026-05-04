# Mac Onboarding — New Machine Setup

---

## 1. Tools

```bash
brew install awscli terraform gh git
brew install python@3.11   # for local bot dev/testing only
npm install -g @modelcontextprotocol/server-github
npm install -g @modelcontextprotocol/server-postgres
```

---

## 2. SSH Key

Copy `id_ed25519_alejocc` from your secure backup to `~/.ssh/`:

```bash
chmod 600 ~/.ssh/id_ed25519_alejocc
chmod 644 ~/.ssh/id_ed25519_alejocc.pub
```

`~/.ssh/config`:
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
# Access Key ID:     <sergio-admin access key>
# Secret Access Key: <sergio-admin secret>
# Region:            us-east-1
# Output:            yaml
```

Verify: `aws sts get-caller-identity` → should show account `670074751531`

---

## 4. GitHub CLI

```bash
gh auth login
# GitHub.com → SSH → id_ed25519_alejocc.pub → paste PAT
```

Verify: `gh auth status` → logged in as `sergiod3v`

---

## 5. Clone Repos

```bash
git clone git@github.com:sergiod3v/city.git
git clone git@github.com:sergiod3v/auto-trading.git
```

---

## 6. Terraform (city repo)

Do not apply locally — applies run via GitHub Actions only.
You can plan locally to test changes before pushing.

```bash
cd city/environments/trading/staging
terraform init
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519_alejocc.pub)"
export TF_VAR_your_ip_cidr="$(curl -s https://checkip.amazonaws.com)/32"
export TF_VAR_env=staging TF_VAR_project=auto-trading TF_VAR_client=myself
terraform plan
```

---

## 7. Claude Code + MCP Servers

```bash
npm install -g @anthropic-ai/claude-code
```

Copy `mcpServers` block from `docs/mcp-servers.md` into `~/.claude/settings.json`.
Fill in:
- `GITHUB_PERSONAL_ACCESS_TOKEN` — sergiod3v PAT
- Postgres connection string — not needed for staging (SQLite, no RDS)

---

## 8. Verify

```bash
# AWS access
aws s3 ls s3://eccensia-tfstate-trading-staging

# GitHub
gh repo view sergiod3v/city

# SSH into staging EC2
ssh -i ~/.ssh/id_ed25519_alejocc ec2-user@52.73.213.253

# Check bot
docker ps
docker logs behemoth -f
```
