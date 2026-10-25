# Authoring Antigravity Skills

Skills are modular, progressive-disclosure packages of knowledge, procedures, and runbooks that teach the agent how to perform specific domain workflows reliably.

---

## 1. Directory Structure

A complete skill folder can reside in either workspace or global scope:

```text
.agents/skills/<skill-name>/
├── SKILL.md             # Required: Primary instruction entry point
├── scripts/             # Optional: Helper scripts executed as black boxes
│   └── helper.py
├── references/          # Optional: Heavy manuals, API docs, schemas
│   └── detailed-guide.md
├── examples/            # Optional: Code snippets, input/output samples
│   └── sample.json
└── resources/           # Optional: Starter templates, assets
    └── template.yaml
```

- **Workspace Path**: `<workspace_root>/.agents/skills/<skill-name>/` (also supports legacy `_agents/`, `.agent/`, `_agent/`). Checked into Git and shared with teammates.
- **Global Path**: `~/.gemini/antigravity/skills/<skill-name>/` (or `~/.gemini/config/skills/<skill-name>/`). Applies across all workspaces on this workstation.

---

## 2. Frontmatter Specifications

Every `SKILL.md` must begin with YAML frontmatter containing `name` and `description`:

```markdown
---
name: my-skill
description: Comprehensive description in third person. States exactly what the skill accomplishes and explicit trigger phrases (e.g. triggers on "/my-skill", "perform X", or "when Y fails").
---
```

### Key Field Rules:

1. **`name`**:
   - Must be lowercase, numbers, and hyphens only (e.g., `nextjs-dev-setup`, `ag-customizer`).
   - Also registers as an immediate chat slash command: typing `/<name>` in the chat prompt directly suggests and triggers this skill.
2. **`description`**:
   - **Critical for Discovery**: Antigravity does not load the body of skills into context by default. It injects a table of skill names and descriptions.
   - Use **third person** ("Helps configure...", "Use when the user requests...").
   - Include specific technical keywords and alternative trigger phrases.
   - Example:
     ```yaml
     description: End-to-end workflow for configuring OpenTelemetry in Next.js App Router applications. Triggers on "/nextjs-otel", "setup otel", "configure opentelemetry", or when inspecting traces.
     ```

---

## 3. Progressive Disclosure Architecture

To protect the model's context window and attention span:

1. **In-file Steps (Tier 1)**:
   - Place the primary step-by-step procedure and binary completion criteria directly in `SKILL.md`.
   - Ensure steps are numbered and clear.
2. **Disclosed Reference (Tier 2)**:
   - Move reference tables, voluminous JSON schemas, or lengthy API specifications into `references/<name>.md`.
   - In `SKILL.md`, link to them using relative markdown links: `[API Reference](references/api-reference.md)`. The agent only opens these files when that specific branch of the workflow is taken.
3. **Black-Box Scripts (Tier 3)**:
   - Encapsulate tedious command chains or complex parsing logic in `scripts/`.
   - Instruct the agent to run scripts with `--help` to discover options rather than dumping entire script source code into LLM context.

---

## 4. Completion Criteria & Leading Words

Following agent engineering principles:

- End each phase on an **observable, binary completion criterion**:
  - Bad: "Verify the configuration looks reasonable."
  - Good: "Run `npm test` and verify that all 14 test cases pass with exit code 0."
- Use **positive prompting**: State what the agent _should_ do, rather than an endless list of prohibitions.
- Avoid no-op filler words ("Be careful", "As an AI assistant"). Keep every line directly actionable.

---

## 5. Standard Skill Template

Use this starter template when generating new skills:

```markdown
---
name: <skill-name>
description: <Concise third-person description with specific trigger keywords>.
---

# <Skill Title>

Brief 1-2 sentence overview of the procedure.

---

## Prerequisites & Detection

List required tools, environment variables, or files to check before running.

---

## Step-by-Step Procedure

### Step 1: Inspection & Planning

1. Inspect the target environment...
2. Verify existing status...

### Step 2: Implementation

1. Create or modify the target configuration...
2. Ensure adherence to standards...

### Step 3: Verification

1. Run verification command: `<command>`
2. Confirm output matches expected pattern...

---

## Decision Trees & Variations

If Scenario A occurs:

- Follow branch A...

If Scenario B occurs:

- Follow branch B...
```
