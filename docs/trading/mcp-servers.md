# MCP Servers — Claude Code Config

Configured in `~/.claude/settings.json` (global, all projects).
These give Claude direct access to GitHub, AWS docs, library docs, and the database.

---

## Active Servers

### GitHub (`github`)
- Package: `@modelcontextprotocol/server-github` (installed globally via npm)
- Auth: PAT stored in `settings.json` as `GITHUB_PERSONAL_ACCESS_TOKEN`
- Gives Claude: read/write PRs, issues, file contents, comments across sergiod3v repos
- Use cases: open PRs from Claude, read issue context, comment on PRs

### AWS Documentation (`aws-docs`)
- Package: `awslabs.aws-documentation-mcp-server` (fetched via `uvx` on demand)
- Auth: none (public docs)
- Gives Claude: inline AWS API reference without web searches
- Use cases: "what's the boto3 signature for ssm get_parameter", CloudFormation resource schemas

### Context7 (`context7`)
- Package: `@upstash/context7-mcp` (fetched via `npx -y` on demand)
- Auth: none
- Gives Claude: up-to-date docs for any npm/PyPI package
- Use cases: CCXT Pro API, SQLAlchemy 2.0 patterns, pandas-ta functions

### PostgreSQL (`postgres`)
- Package: `@modelcontextprotocol/server-postgres` (installed globally via npm)
- Auth: RDS connection string in args (fill after terraform apply)
- Gives Claude: run SQL queries against behemoth RDS directly from chat
- Use cases: inspect candle_log rows, check cycles, debug indicators

---

## Settings Block

```json
"mcpServers": {
  "token-savior-recall": {
    "command": "uvx",
    "args": ["token-savior-recall"],
    "env": {
      "WORKSPACE_ROOTS": "C:\\Users\\sergi\\OneDrive\\Escritorio\\Workspace",
      "TOKEN_SAVIOR_CLIENT": "claude-code"
    }
  },
  "github": {
    "command": "npx",
    "args": ["@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "<your-pat>"
    }
  },
  "aws-docs": {
    "command": "uvx",
    "args": ["awslabs.aws-documentation-mcp-server@latest"],
    "env": {
      "FASTMCP_LOG_LEVEL": "ERROR"
    }
  },
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  },
  "postgres": {
    "command": "npx",
    "args": [
      "@modelcontextprotocol/server-postgres",
      "postgresql://behemoth_app:<password>@<rds-endpoint>:5432/behemoth"
    ]
  }
}
```

---

## Setup on New Machine

```bash
# Install npm-based servers globally
npm install -g @modelcontextprotocol/server-github @modelcontextprotocol/server-postgres

# uvx and npx servers are self-fetching — no install needed
# uvx comes with uv: brew install uv (Mac) / pip install uv (any)
```

Then copy the `mcpServers` block above into `~/.claude/settings.json` and fill:
- `<your-pat>` — GitHub PAT with repo + PR + issues scopes for sergiod3v
- `<password>` — fetch from SSM: `aws ssm get-parameter --name behemoth.staging.db.password --with-decryption --query Parameter.Value --output text --region us-east-1`
- `<rds-endpoint>` — from `terraform output rds_endpoint` or GitHub Actions apply output

---

## Verifying MCP Servers

After starting a new Claude Code session, run `/mcp` to see connected servers.
Each should show as `connected` with its available tools listed.

If a server shows `failed`:
- Check `~/.claude/settings.json` for syntax errors
- Verify the package is installed: `npm list -g @modelcontextprotocol/server-github`
- Check the PAT / connection string values are filled (not PLACEHOLDER)
