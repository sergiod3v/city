# Scripts — Infra Management

Central tool for starting/stopping infrastructure. EC2 is the only resource with meaningful cost (~$8.50/mo running, ~$0 stopped).

## Usage

```bash
# From city/ root
python scripts/manage.py <project> <env> <on|off|status>

# Examples
python scripts/manage.py auto-trading staging status
python scripts/manage.py auto-trading staging off
python scripts/manage.py auto-trading staging on
```

## Shell shortcuts

```bash
# Staging
scripts/auto-trading/staging/spin-up.sh
scripts/auto-trading/staging/shut-down.sh

# Prod (when it exists)
scripts/auto-trading/prod/spin-up.sh
scripts/auto-trading/prod/shut-down.sh
```

## Requirements

- Python 3.x
- `boto3` (`pip install boto3`)
- AWS credentials configured (`aws configure` or env vars)
- Your IAM user needs `ec2:DescribeInstances`, `ec2:StartInstances`, `ec2:StopInstances`, `ec2:DescribeAddresses`

## How it works

Discovers EC2 by tags (`project` + `env`) — no hardcoded IPs or instance IDs. Works on Mac and Windows (Git Bash / CMD).

`on` — starts EC2, waits until running, prints IP and SSH command  
`off` — stops EC2, waits until stopped, shows cost saved  
`status` — shows state, uptime, estimated session cost  
