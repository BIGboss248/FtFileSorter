# Autofix Rule Categories & Precedence Matrix

This reference defines the schema, precedence rules, and categorization taxonomy for `autofix.json`.

---

## 1. Rule Schema

```json
[
  {
    "Rule_number": 1,
    "Category": "CODE",
    "Instruction": "Never use default exports for React components - always use named exports.",
    "Why": "Ensures consistency with the codebase and simplifies refactoring."
  }
]
```

---

## 2. Rule Categorization Matrix

| Category | Description | Examples |
| :--- | :--- | :--- |
| `STYLE` | Code formatting, naming conventions, import ordering, comments | `"Always use camelCase for helper functions"` |
| `CODE` | Language patterns, library choices, type definitions, error handling | `"Never use any in TypeScript; use unknown with type guards"` |
| `ARCH` | Directory structure, module boundaries, architectural layers | `"API routes live in src/server/routes/, not src/api/"` |
| `TOOL` | CLI commands, build tools, package managers, testing frameworks | `"Always use pnpm instead of npm or yarn"` |
| `PROCESS`| Git workflow, commit messages, PR requirements, test gates | `"Never add emojis to commit messages"` |
| `DATA` | Database schemas, migrations, caching strategies, state shapes | `"Always include created_at and updated_at timestamps on tables"` |
| `UX` / `UI` | UI behaviors, copy conventions, accessibility standards, card header wraps | `"Always provide an explicit aria-label for icon-only buttons"` |
| `OTHER` | General project or domain-specific preferences | `"Always document public API endpoints in markdown table format"` |

---

## 3. Conflict Resolution & Precedence

1. **Higher Number Wins**: When two rules provide conflicting instructions, the higher `Rule_number` (newer rule) takes precedence over older rules.
2. **Immutability**: Never delete existing rules to preserve historical audit trail. If an older rule is superseded, write the new rule with a higher number and document the reason in `Why`.
3. **Imperative Phrasing**: Always write instructions in clear imperative terms (`"Never/Always do X - because Y"`).

