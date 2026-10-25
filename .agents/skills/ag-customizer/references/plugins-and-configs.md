# Antigravity Plugins & JSON Configurations

This guide covers how to bundle customizations into distributable **Plugins** and how to use **`skills.json`** and **`plugins.json`** to manage external paths and shared team repositories.

---

## 1. Plugins Architecture

A plugin bundles skills, rules, lifecycle hooks, and MCP servers into a single cohesive, namespaced package.

### Directory Layout:

```text
.agents/plugins/<plugin-name>/
├── plugin.json          # Required: Manifest file
├── mcp_config.json      # Optional: MCP servers bundled with this plugin
├── hooks.json           # Optional: Lifecycle hooks registered by this plugin
├── rules/               # Optional: Rules applied when plugin is active
│   └── AGENTS.md        # Recommended: Consolidated rule definitions
└── skills/              # Optional: Skills exposed by this plugin
    └── <skill-name>/
        └── SKILL.md
```

### Manifest (`plugin.json`):

```json
{
  "name": "fullstack-toolkit",
  "description": "Comprehensive development tools and workflows for our web stack."
}
```

- A plugin can default to inactive by including `"disabled": true` in `plugin.json`.

### Managing Plugin State:

Plugin enable/disable status is recorded in your workstation's `config.json`:

```json
{
  "plugins": {
    "fullstack-toolkit": {
      "enabled": true
    }
  }
}
```

`config.json` settings override the default in `plugin.json`.

---

## 2. JSON Configuration Files (`skills.json` / `plugins.json`)

When skills or plugins reside in non-standard paths, across monorepos, or in shared git submodules, register them explicitly using JSON manifests.

- **Skills Manifest**: `.agents/skills.json` or `~/.gemini/config/skills.json`
- **Plugins Manifest**: `.agents/plugins.json` or `~/.gemini/config/plugins.json`

### Configuration Schema:

Both files share the exact same schema:

```json
{
  "inherits": [
    {
      "path": "tools/shared-team-config/skills.json",
      "include_only": ["deploy-.*", "security-check"],
      "exclude": [".*-experimental"]
    }
  ],
  "entries": [
    {
      "path": "internal-tools/skills",
      "exclude": ["legacy-.*"]
    },
    {
      "path": "~/shared-developer-skills"
    }
  ]
}
```

### Field Definitions:

| Field              | Type     | Description                                                                                                 |
| :----------------- | :------- | :---------------------------------------------------------------------------------------------------------- |
| **`entries`**      | array    | List of directory paths to scan for skills or plugins.                                                      |
| **`inherits`**     | array    | List of other JSON configuration files to merge into this one.                                              |
| **`path`**         | string   | Path to target. Can be absolute (`/opt/...`), home-relative (`~/...`), or workspace-relative (`tools/...`). |
| **`include_only`** | string[] | Array of regex patterns. If specified, only customizations matching at least one pattern will load.         |
| **`exclude`**      | string[] | Array of regex patterns. Customizations matching any pattern are skipped.                                   |

---

## 3. Team Sharing Workflow via Version Control

To distribute standardized skills and plugins to an entire engineering team:

1. Commit the shared skills to a common directory in the repository (e.g. `engineering/tools/skills/`).
2. Add `.agents/skills.json` at the repository root:
   ```json
   {
     "entries": [{ "path": "engineering/tools/skills" }]
   }
   ```
3. When any developer checks out the repo and opens Antigravity, `.agents/skills.json` is discovered automatically, making the team skills immediately available.
