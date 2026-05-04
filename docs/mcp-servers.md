# MCP Servers — Claude Code Config

Configured in `~/.claude/settings.json` (global).

## Servers

| Server | Package | Auth |
|--------|---------|------|
| `github` | `@modelcontextprotocol/server-github` (npm global) | PAT |
| `aws-docs` | `awslabs.aws-documentation-mcp-server` (uvx) | None |
| `context7` | `@upstash/context7-mcp` (npx -y) | None |
| `postgres` | `@modelcontextprotocol/server-postgres` (npm global) | Connection string |
| `token-savior-recall` | `token-savior-recall` (uvx) | None |

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
    "args": ["@modelcontextprotocol/server-postgres", "<connection-string>"]
  }
}
```

## New machine install

```bash
npm install -g @modelcontextprotocol/server-github @modelcontextprotocol/server-postgres
# uvx: brew install uv (Mac)
```

Postgres: not needed for staging (SQLite). Add for prod when RDS exists.
