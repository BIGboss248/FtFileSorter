# Model Context Protocol (MCP) Configuration Guide

The Model Context Protocol (MCP) connects Antigravity and workspace OpenCode agents to external tool providers, databases, web services, and APIs.

---

## 1. Configuration File Locations & Multi-Target Rules

> [!IMPORTANT]
> **Multi-Target MCP Registration Rule:**
> 1. **Antigravity (AG) Global Scope**: Antigravity only discovers and loads MCP servers configured globally on the host system (`~/.gemini/antigravity/mcp_config.json` and `~/.gemini/config/mcp_config.json`). Global registration must be performed **strictly for AGY only** — never register MCP servers globally for other coding agents (such as `~/.config/opencode/opencode.json`, Claude Desktop, or Cursor).
> 2. **Workspace Scope (Antigravity & Standard)**: Maintain `<workspace_root>/mcp.json` and `<workspace_root>/.agents/mcp_config.json` for repository portability.
> 3. **Workspace Scope (OpenCode — Local to Workspace ONLY)**: Always also register MCP servers in `<workspace_root>/opencode.json` under `"mcp": { "servers": { ... } }` so OpenCode can read and load them locally within the project.
> 4. **Plugin Scope**: `.agents/plugins/<plugin_name>/mcp_config.json` (active when the plugin is loaded).

---

## 2. Schema Comparison: Antigravity vs. OpenCode (`opencode.json`)

Antigravity (`mcp_config.json` / `mcp.json`) and OpenCode (`<workspace_root>/opencode.json`) use distinct JSON structures. Whenever adding or updating an MCP server, write the appropriate format to each target file:

| Feature / Property            | Antigravity (`mcp_config.json`, `mcp.json`)             | OpenCode Workspace (`<workspace_root>/opencode.json`)        |
| :---------------------------- | :------------------------------------------------------ | :----------------------------------------------------------- |
| **Root Object Path**          | `"mcpServers": { "<name>": { ... } }`                   | `"mcp": { "servers": { "<name>": { ... } } }`                |
| **Server Type Discriminator** | Implicit (inferred from `command` vs `serverUrl`)       | Explicit: `"type": "local"` or `"type": "remote"`            |
| **Local Executable & Args**   | `"command": "npx"`, `"args": ["-y", "pkg"]`             | Single array: `"command": ["npx", "-y", "pkg"]`              |
| **Environment Variables**     | `"env": { "KEY": "VALUE" }`                             | `"environment": { "KEY": "VALUE" }`                          |
| **Remote Server Endpoint**    | `"serverUrl": "https://..."` (`url` in `mcp.json`)      | `"url": "https://..."`                                       |
| **Remote HTTP Headers**       | `"headers": { "Authorization": "Bearer ..." }`          | `"headers": { "Authorization": "Bearer ..." }`               |
| **Scope Policy**              | Workspace + Global AGY (`~/.gemini/...`)                | **Workspace Local ONLY** (`<workspace_root>/opencode.json`)  |

---

## 3. Transport Configurations

### Transport 1: Local `stdio` Transport

Spawns a local executable process and communicates over standard input/output.

#### A. Antigravity Schema (`.agents/mcp_config.json`, `mcp.json`, `~/.gemini/antigravity/mcp_config.json`)

```json
{
  "mcpServers": {
    "sqlite-server": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sqlite",
        "./data/database.db"
      ],
      "env": {
        "SQLITE_READONLY": "true"
      },
      "cwd": "${workspaceFolder}"
    }
  }
}
```

| Property  | Type     | Required | Description                                                                           |
| :-------- | :------- | :------- | :------------------------------------------------------------------------------------ |
| `command` | string   | Yes      | The executable binary to spawn (`node`, `npx`, `python`, `uvx`, or full binary path). |
| `args`    | string[] | No       | Array of arguments passed to the command.                                             |
| `env`     | object   | No       | Custom environment variables injected into the process.                               |
| `cwd`     | string   | No       | Working directory for the server process.                                             |

#### B. OpenCode Workspace Schema (`<workspace_root>/opencode.json`)

```json
{
  "mcp": {
    "servers": {
      "sqlite-server": {
        "type": "local",
        "command": [
          "npx",
          "-y",
          "@modelcontextprotocol/server-sqlite",
          "./data/database.db"
        ],
        "environment": {
          "SQLITE_READONLY": "true"
        }
      }
    }
  }
}
```

| Property      | Type     | Required | Description                                                                     |
| :------------ | :------- | :------- | :------------------------------------------------------------------------------ |
| `type`        | string   | Yes      | Must be `"local"` for stdio servers.                                            |
| `command`     | string[] | Yes      | Combined array of the executable binary followed by all command-line arguments. |
| `environment` | object   | No       | Environment variables map (`Record<string, string>`) passed to the process.     |

---

### Transport 2: Remote SSE / Streamable HTTP Transport

Connects to a remote server over HTTP using Server-Sent Events (SSE) or Streamable HTTP.

#### A. Antigravity Schema (`.agents/mcp_config.json`, `~/.gemini/antigravity/mcp_config.json`)

> [!IMPORTANT]
> **Use `serverUrl` in Antigravity configs**: Always specify `serverUrl` in Antigravity `mcp_config.json` files. Legacy properties such as `url` or `httpUrl` are not supported by Antigravity.

```json
{
  "mcpServers": {
    "remote-api-server": {
      "serverUrl": "https://mcp.internal.company.com/sse",
      "headers": {
        "Authorization": "Bearer YOUR_ACCESS_TOKEN",
        "X-Custom-Header": "production"
      }
    }
  }
}
```

#### B. OpenCode Workspace Schema (`<workspace_root>/opencode.json`)

> [!IMPORTANT]
> **Use `"type": "remote"` and `"url"` in OpenCode**: OpenCode requires `"type": "remote"` and the `"url"` key inside `mcp.servers`.

```json
{
  "mcp": {
    "servers": {
      "remote-api-server": {
        "type": "remote",
        "url": "https://mcp.internal.company.com/sse",
        "headers": {
          "Authorization": "Bearer YOUR_ACCESS_TOKEN",
          "X-Custom-Header": "production"
        }
      }
    }
  }
}
```

---

### Adding to `<workspace_root>/opencode.json` via OpenCode CLI

If the `opencode` CLI is installed, you can also register servers directly into the workspace `<workspace_root>/opencode.json` (never pass `--global`):

- **Local (`stdio`) server** (in PowerShell, quote `'--'` so PowerShell passes the separator to `opencode`):
  ```powershell
  opencode mcp add sqlite-server --env SQLITE_READONLY=true '--' npx -y @modelcontextprotocol/server-sqlite ./data/database.db
  ```
- **Remote server**:
  ```powershell
  opencode mcp add remote-api-server --url https://mcp.internal.company.com/sse --header Authorization=Bearer_YOUR_ACCESS_TOKEN
  ```

---

## 4. Authentication Mechanisms

### Option A: Google Application Default Credentials (ADC)

For connecting to Google Cloud services or internal Google APIs in Antigravity:

```json
{
  "mcpServers": {
    "google-cloud-mcp": {
      "serverUrl": "https://cloud-mcp.googleapis.com/sse",
      "authProviderType": "google_credentials"
    }
  }
}
```

Requires local ADC login via Google Cloud CLI:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

### Option B: OAuth 2.0 (Dynamic Client Registration & Manual)

If the server supports OAuth Dynamic Client Registration (DCR), specify only `serverUrl` (in Antigravity) or `url` (in OpenCode). If manual client credentials are required:

```json
{
  "mcpServers": {
    "oauth-service": {
      "serverUrl": "https://api.example.com/mcp/",
      "oauth": {
        "clientId": "YOUR_CLIENT_ID",
        "clientSecret": "YOUR_CLIENT_SECRET"
      }
    }
  }
}
```

> [!NOTE]
> The redirect URI registered with your OAuth provider for Antigravity must be:
> `https://antigravity.google/oauth-callback`
> In Antigravity IDE, authenticate via **Settings (Ctrl+,) > Customizations > Authenticate**. For OpenCode, run `opencode mcp auth <name>`.

---

## 5. Operational Controls & Disabling Servers

### In Antigravity (`mcp_config.json`):

> [!WARNING]
> **`agy.exe` Disabling Behavior (Rule 20):**
> In Antigravity global MCP configurations (`~/.gemini/antigravity/mcp_config.json` and `~/.gemini/config/mcp_config.json`), `agy.exe` does **not** respect `"disabled": true` inside the `mcpServers` object and will still launch the child processes. To properly disable an MCP server in AGY, move it completely out of `mcpServers` into a separate `_disabledMcpServers` object.

You can filter specific dangerous tools without disabling the server using `disabledTools`:

```json
{
  "mcpServers": {
    "database-tools": {
      "command": "python",
      "args": ["-m", "db_mcp_server"],
      "disabledTools": ["drop_table", "truncate_table", "delete_records"]
    }
  },
  "_disabledMcpServers": {
    "experimental-service": {
      "serverUrl": "https://staging.mcp.example.com/"
    }
  }
}
```

---

## 6. Ready-to-Use Dual Server Recipes (Antigravity + OpenCode)

### Recipe 1: Next.js + Codebase Memory + Playwright Stack

**Antigravity (`mcp.json`, `.agents/mcp_config.json`, `~/.gemini/antigravity/mcp_config.json`):**

```json
{
  "mcpServers": {
    "next-devtools": {
      "command": "npx",
      "args": ["-y", "next-devtools"]
    },
    "codebase-memory": {
      "command": "codebase-memory-mcp",
      "args": []
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

**OpenCode Workspace (`<workspace_root>/opencode.json`):**

```json
{
  "mcp": {
    "servers": {
      "next-devtools": {
        "type": "local",
        "command": ["npx", "-y", "next-devtools"]
      },
      "codebase-memory": {
        "type": "local",
        "command": ["codebase-memory-mcp"]
      },
      "playwright": {
        "type": "local",
        "command": ["npx", "-y", "@playwright/mcp@latest"]
      }
    }
  }
}
```

### Recipe 2: GitHub MCP

**Antigravity:**

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxx"
      }
    }
  }
}
```

**OpenCode Workspace (`<workspace_root>/opencode.json`):**

```json
{
  "mcp": {
    "servers": {
      "github": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
        "environment": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxx"
        }
      }
    }
  }
}
```

### Recipe 3: PostgreSQL MCP

**Antigravity:**

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://user:password@localhost:5432/mydb"
      ]
    }
  }
}
```

**OpenCode Workspace (`<workspace_root>/opencode.json`):**

```json
{
  "mcp": {
    "servers": {
      "postgres": {
        "type": "local",
        "command": [
          "npx",
          "-y",
          "@modelcontextprotocol/server-postgres",
          "postgresql://user:password@localhost:5432/mydb"
        ]
      }
    }
  }
}
```
