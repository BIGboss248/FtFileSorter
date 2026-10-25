# Frontmatter & Triggers Guide

The `description` in YAML frontmatter is the single most critical field in a skill. In modern agent systems (like Google Antigravity, Claude Code, Cursor, Windsurf), skills use **progressive disclosure**: the body of `SKILL.md` is **not** loaded into context by default. The agent only sees the skill's `name` and `description` to decide whether to activate it.

---

## 1. Specification Requirements

According to the Open Agent Skills specification (`agentskills.io`):

| Field             | Type   | Constraints                                                                                                                                          | Best Practice                                                                                                                   |
| :---------------- | :----- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **`name`**        | String | 1–64 characters. Only lowercase alphanumeric (`a-z`, `0-9`) and hyphens (`-`). Cannot start/end with `-` or contain `--`. Must match directory name. | Be descriptive and concise: `docker-deploy`, `nextjs-component-dev`, `skill-creator`.                                           |
| **`description`** | String | 1–1024 characters (Recommended: **<150–200 characters**, strictly **1–2 concise sentences**).                                                        | Clearly declare **what** the skill accomplishes and **when / trigger phrases** to load it. Keep free of implementation details. |
| **`license`**     | String | Optional. SPDX identifier (e.g. `Apache-2.0`, `MIT`).                                                                                                | Include if sharing publicly.                                                                                                    |
| **`metadata`**    | Map    | Optional. String key-value pairs (e.g. `version`, `author`).                                                                                         | Use for versioning or plugin associations.                                                                                      |

---

## 2. Writing Ultra-Minimal High-Trigger Descriptions

### The Golden Rule

> **"A good description states WHAT the skill does and WHEN to trigger it in 1–2 sentences (<150–200 chars), with zero implementation bloat."**

### 4 Core Principles

1. **Strict Brevity & Context Budget**: The agent loads all skill descriptions into its initial system prompt. Long descriptions waste initial context tokens. Keep it strictly to 1–2 short sentences.
2. **WHAT and WHEN Only**: State what capabilities it provides and list explicit trigger scenarios/keywords. NEVER explain _how_ it works internally or what procedural steps it follows.
   - ❌ _Bloated_: "Configures Jest and Storybook by running npm install, copying test templates from resources/templates, editing jest.config.ts with ts-jest, modifying package.json scripts, and running verification tests."
   - ✅ _Ultra-Lean_: "Configure Jest unit tests, Storybook CSF3 stories, and Playwright E2E testing for Next.js. Use when setting up testing suites, writing stories, or configuring test runners."
3. **Third-Person Perspective**: Write in active third person.
   - ❌ _Weak_: "I can help you review your code."
   - ✅ _Strong_: "Review code for performance, security, and team standards. Use when reviewing PRs, diffs, or auditing code quality."
4. **Keyword & Trigger Phrase Density**: Include exact terms, slash commands, or user phrases that should activate the skill.
   - Example triggers: _"create a new skill"_, _"scaffold skill"_, _"/skill-creator"_, _"audit database migrations"_.

---

## 3. Description Anti-Patterns to Avoid

| Anti-Pattern                                                                     | Why It Fails                                                                   | Better Alternative                                                                                                              |
| :------------------------------------------------------------------------------- | :----------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **Vague / Over-general** (`"Helps with Next.js development."`)                   | Triggers on every single Next.js prompt, polluting context and wasting tokens. | `"Configure Next.js OpenTelemetry instrumentation. Use when adding OTel, tracing request spans, or configuring APM exporters."` |
| **Implementation / Procedural Dump** (`"Reads file X, replaces AST, runs Y..."`) | Wastes system prompt tokens and confuses trigger matching.                     | `"Audit UI components for accessibility (WCAG AA/AAA). Use when checking a11y, semantic HTML, or ARIA attributes."`             |
| **Overly Long Multi-Paragraph Descriptions**                                     | Bloats agent system prompt and increases latency across every turn.            | Keep strictly under 200 characters in 1–2 sentences.                                                                            |

---

## 4. Multi-Line YAML Frontmatter Formatting

Always use YAML folded block scalars (`>-`) or single lines for clean readability:

```yaml
---
name: nextjs-i18n-setup
description: >-
  Configure next-intl internationalization for Next.js App Router. Use when
  setting up multi-language routing, translation dictionaries, or locale middleware.
---
```
