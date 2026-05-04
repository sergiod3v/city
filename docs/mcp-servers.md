# MCP Servers — Claude Code Config

Configured in `~/.claude/settings.json` (global).

## Servers

| Server | Package | Auth | Gives Claude |
|--------|---------|------|-------------|
| `github` | `@modelcontextprotocol/server-github` (npm global) | PAT | Read/write PRs, issues, files |
| `aws-docs` | `awslabs.aws-documentation-mcp-server` (uvx) | None | Inline AWS API reference |
| `context7` | `@upstash/context7-mcp` (npx -y) | None | Up-to-date library docs (boto3, CCXT, SQLAlchemy) |
| `postgres` | `@modelcontextprotocol/server-postgres` (npm global) | Connection string | SQL queries against DB |
| `token-savior-recall` | `token-savior-recall` (uvx) | None | Symbol/function lookup |

## Settings block

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
    "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "<your-pat>" }
  },
  "aws-docs": {
    "command": "uvx",
    "args": ["awslabs.aws-documentation-mcp-server@latest"],
    "env": { "FASTMCP_LOG_LEVEL": "ERROR" }
  },
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"]
  },
  "postgres": {
    "command": "npx",
    "args": ["@modelcontextprotocol/server-postgres", "REPLACE_WITH_CONNECTION_STRING"]
  }
}
```

## New machine install

```bash
npm install -g @modelcontextprotocol/server-github @modelcontextprotocol/server-postgres
# uvx and npx servers self-fetch — no install needed
# uv: brew install uv (Mac)
```

Postgres connection string for staging: not applicable (SQLite, no RDS).
Add when prod RDS exists: `postgresql://behemoth_app:<password>@<rds-endpoint>:5432/behemoth`
