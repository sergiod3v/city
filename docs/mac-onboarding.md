# Mac Onboarding — New Machine Setup

## 1. Tools

```bash
brew install awscli terraform gh git python@3.11
npm install -g @modelcontextprotocol/server-github @modelcontextprotocol/server-postgres
```

## 2. SSH Key

Copy `id_ed25519_alejocc` from secure backup to `~/.ssh/`:

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

## 3. AWS CLI

```bash
aws configure
# Region: us-east-1 / Output: yaml
```

## 4. GitHub CLI

```bash
gh auth login
# GitHub.com → SSH → id_ed25519_alejocc.pub → paste PAT
```

## 5. Clone

```bash
git clone git@github.com:sergiod3v/city.git
git clone git@github.com:sergiod3v/auto-trading.git
```

## 6. Terraform

Don't apply locally — applies run via GitHub Actions only. Plan locally to test:

```bash
cd city/environments/trading/staging
terraform init
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519_alejocc.pub)"
export TF_VAR_your_ip_cidr="$(curl -s https://checkip.amazonaws.com)/32"
export TF_VAR_env=staging TF_VAR_project=auto-trading TF_VAR_client=myself
terraform plan
```

## 7. Claude Code + MCP

```bash
npm install -g @anthropic-ai/claude-code
```

Copy `mcpServers` block from `docs/mcp-servers.md` into `~/.claude/settings.json`. Fill PAT.

## 8. Shell Aliases (~/.zshrc or ~/.bashrc)

Add to your shell profile so EC2/Eccensia commands work from terminal:

```bash
# EC2 lifecycle (requires city repo cloned at ~/city or adjust path)
_CITY="$HOME/city"
alias ec2-up="bash '$_CITY/infra.sh' up"
alias ec2-down="bash '$_CITY/infra.sh' down"
alias ec2-status="bash '$_CITY/infra.sh' status"

# SSH (requires ~/.ssh/config Host eccensia entry)
alias ec2-ssh="ssh eccensia"

# ~/.ssh/config entry needed:
# Host eccensia
#   HostName <EC2_PUBLIC_IP_OR_DOMAIN>
#   User ubuntu
#   IdentityFile ~/.ssh/id_ed25519_alejocc

# Docker Compose service control (tunnels over SSH)
_ec2_compose() { ssh eccensia "cd /opt/eccensia && docker compose $*"; }

svc-up()      { _ec2_compose "up -d $1"; }
svc-down()    { _ec2_compose "stop $1"; }
svc-restart() { _ec2_compose "restart $1"; }
svc-pull()    { _ec2_compose "pull $1 && docker compose up -d $1"; }
svc-logs()    { ssh eccensia "cd /opt/eccensia && docker compose logs --tail ${2:-50} -f $1"; }
svc-status()  { _ec2_compose "ps"; }

# Per-service shortcuts
alias behemoth-restart="svc-restart behemoth"
alias behemoth-logs="svc-logs behemoth"
alias eccensia-restart="svc-restart eccensia"
alias eccensia-logs="svc-logs eccensia"
mercadillo-restart() { ssh eccensia "cd /opt/bijadillo && docker compose restart mercadillo"; }
mercadillo-logs()    { ssh eccensia "cd /opt/bijadillo && docker compose logs --tail ${1:-50} -f mercadillo"; }
alias nginx-restart="svc-restart nginx"
alias nginx-logs="svc-logs nginx"
```

After adding: `source ~/.zshrc`

## 9. Verify

```bash
aws s3 ls s3://eccensia-tfstate-trading-staging
gh repo view sergiod3v/city

# Get EC2 IP then SSH
python city/scripts/manage.py auto-trading staging status
```
