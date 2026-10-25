# Authoring Antigravity Rules

Rules are persistent constraints, coding standards, architectural guardrails, and style guidelines that guide the agent across workspace or global scopes.

---

## 1. Rule Locations & Precedence

| Scope                       | Location                       | Activation Behavior                                                                 |
| :-------------------------- | :----------------------------- | :---------------------------------------------------------------------------------- |
| **Global Rule**             | `~/.gemini/GEMINI.md`          | Injected across all projects on this machine.                                       |
| **Workspace Hierarchical**  | `AGENTS.md` or `GEMINI.md`     | Placed at repository root or subdirectories. Loaded as agent navigates paths.       |
| **Modular Workspace Rules** | `.agents/rules/<rule-name>.md` | Configurable per-rule activation (`always_on`, `glob`, `model_decision`, `manual`). |

---

## 2. Activation Modes for Modular Rules (`.agents/rules/*.md`)

Each file inside `.agents/rules/<rule-name>.md` can specify an activation mode in its frontmatter:

### Mode 1: Always On (`always_on`)

The rule is injected into every conversation turn. Use strictly for critical global constraints.

```markdown
---
trigger: always_on
---

# Critical Safety Protocol

Never commit secrets, API keys, or credentials to git.
```

### Mode 2: Model Decision (`model_decision`)

The model evaluates the description and decides whether to load the rule for the task.

```markdown
---
trigger: model_decision
description: Applies when working with database migrations, Drizzle ORM schemas, or SQL queries.
---

# Database Guidelines

Always generate and inspect migration files before running migrations in production.
```

### Mode 3: File Glob (`glob`)

Automatically injected whenever files matching the pattern are opened, read, or modified.

```markdown
---
trigger: glob
globs:
  - "src/**/*.tsx"
  - "components/**/*.tsx"
---

# React Component Rules

- Use Functional Components with TypeScript interfaces.
- Separate UI markup from business logic hooks.
```

### Mode 4: Manual Mention (`manual`)

Only loaded into context when explicitly referenced by the user in the prompt using `@<rule-name>.md`.

```markdown
---
trigger: manual
---

# Security Audit Checklist

Perform exhaustive threat modeling against OWASP Top 10 vulnerabilities.
```

---

## 3. Character Budget & File Linking

1. **Character Budget**:
   - Each rule file is capped at **12,000 characters**.
   - If guidelines exceed this length, split into focused modular rule files under `.agents/rules/`.
2. **Context Inclusion via `@filename`**:
   - You can include external files into rules using `@filename` syntax:
     - `@local-guide.md` (relative to the rule file).
     - `@/docs/standards.md` (resolved from repo root).
   - This keeps individual rule files compact while pulling in shared specifications dynamically.

---

## 4. Best Practices for High-Impact Rules

- **State the Positive**: Frame directives positively ("Use pnpm run build", "Structure errors with custom AppError class") rather than negative prohibitions ("Don't use npm", "Don't throw generic strings"). The model anchors strongly on the explicit concept stated.
- **Single Source of Truth**: Never duplicate a rule across multiple files. Keep one canonical file and reference it if needed.
- **Auto-Deduplication**: Antigravity automatically deduplicates rules by resolved path; a rule discovered through multiple directory walks is only injected once.
- **Permission Alignment**: Avoid embedding one-liner command chains (`&&`, `||`, `;`) in recommended instructions, as chained commands can bypass prefix-matching allowlists.
