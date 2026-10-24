# Flutter AI Tools & MCP Server Integration (`flutter-dev-setup`)

Official Reference: [How Flutter AI tools work](https://docs.flutter.dev/ai/tools)

The Flutter and Dart AI tooling ecosystem consists of complementary components:
1. **Agent Skills**: Procedural blueprints for Flutter and Dart development workflows.
2. **Dart and Flutter MCP Server**: Local stdio server exposing SDK diagnostics, symbol resolution, and runtime introspection.
3. **Developer Knowledge MCP Server**: Remote documentation search server providing live access to `docs.flutter.dev` and `dart.dev`.
4. **Package Skills**: Skills distributed via `pub.dev` packages installed via `dart run skills get`.
5. **Specialized Agents**: Focused personas like the official `@flutter_a11y_agent` (Accessibility Auditor).
6. **Agent Rules**: Persistent project constraints and conventions.

---

## 1. Installing Official Agent Skills Repositories

When scaffolding the development environment for a Flutter project, the agent must install and clone/sync the official skills:

### A. Official Repositories
- [**`flutter/agent-plugins`**](https://github.com/flutter/agent-plugins): Provides Flutter-specific skills (widget construction, navigation, responsive layouts, state management).
- [**`dart-lang/skills`**](https://github.com/dart-lang/skills): Provides Dart language skills (unit testing, dependency resolution, static analysis remediation).

### B. Installation Procedure in Project Workspace
1. In the target Flutter repository root, create `.agents/skills/`.
2. Clone or fetch official Flutter and Dart skills into `.agents/skills/`:
   ```powershell
   # PowerShell clone/sync helper
   git clone --depth 1 https://github.com/flutter/agent-plugins.git .temp_flutter_skills
   Copy-Item -Path .temp_flutter_skills/skills/* -Destination .agents/skills/ -Recurse -Force
   Remove-Item -Path .temp_flutter_skills -Recurse -Force

   git clone --depth 1 https://github.com/dart-lang/skills.git .temp_dart_skills
   Copy-Item -Path .temp_dart_skills/skills/* -Destination .agents/skills/ -Recurse -Force
   Remove-Item -Path .temp_dart_skills -Recurse -Force
   ```
3. Install package-specific skills from dependencies listed in `pubspec.yaml`:
   ```powershell
   dart run skills get
   ```

---

## 2. Antigravity MCP Discovery & Global Configuration

Per Rule 13, Rule 14, and `agy-customizations`:
- Antigravity (AG) discovers and loads MCP servers **globally on the host system**:
  - `~/.gemini/antigravity/mcp_config.json`
  - `~/.gemini/config/mcp_config.json`
- Workspace configurations (`mcp.json` or `.vscode/mcp.json`) are maintained for workspace portability.
- **Strict AG Scope**: Configure MCP servers strictly for Google Antigravity / AGY only.
- **Proper Disabling**: Antigravity ignores `"disabled": true` inside `mcpServers`. Move disabled servers outside `mcpServers` (e.g. into `_disabledMcpServers`).

### MCP Configuration Schema

Add the Dart and Flutter MCP server and Developer Knowledge MCP server to both global AG config files (`~/.gemini/antigravity/mcp_config.json` and `~/.gemini/config/mcp_config.json`):

```json
{
  "mcpServers": {
    "dart-flutter-mcp": {
      "command": "dart",
      "args": ["run", "dart_mcp_server"]
    },
    "developer-knowledge": {
      "url": "https://developers.google.com/knowledge/mcp"
    }
  }
}
```

---

## 3. Specialized Agents & Agent Rules

- **Accessibility Agent (`@flutter_a11y_agent`)**: Available natively in Google Antigravity. Performs semantic label checks, tap target validation ($\ge 48\times 48$), contrast checks, and automated `Semantics` fixes.
- **Agent Rules**: Mirror official rules from `flutter/agent-plugins/rules` into `.agents/rules/` for persistent context.
