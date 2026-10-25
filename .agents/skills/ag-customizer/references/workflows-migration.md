# Workflows to Skills Migration Runbook

Legacy workflows (`.agents/workflows/*.md` or `~/.gemini/config/workflows/*.md`) are deprecated in Antigravity. Modern **Skills** provide all the capabilities of workflows, plus semantic LLM activation, multi-file progressive disclosure, helper script support, and first-class slash command shortcuts.

---

## 1. Migration Overview & Mapping

| Feature                    | Legacy Workflow               | Modern Skill                                   |
| :------------------------- | :---------------------------- | :--------------------------------------------- |
| **Path**                   | `.agents/workflows/<name>.md` | `.agents/skills/<name>/SKILL.md`               |
| **Slash Command**          | `/<name>`                     | `/<name>` (native support)                     |
| **Autonomous Discovery**   | Weak/Limited                  | Semantic model-matching via `description`      |
| **Multi-file / Scripts**   | Single markdown file only     | Full directory (`scripts/`, `references/`)     |
| **Progressive Disclosure** | None (injected in full)       | Progressive (name & description indexed first) |

---

## 2. Step-by-Step Migration Procedure

### Step 1: Scan for Workflows

Check the following locations for legacy `.md` workflow files:

- Workspace: `<workspace>/.agents/workflows/*.md` (or `_agents/`, `.agent/`)
- Global: `~/.gemini/config/global_workflows/*.md` or `~/.gemini/config/workflows/*.md`

### Step 2: Convert to Skill Format

For each discovered workflow:

1. **Check for existing skill**: If `<target_skills_dir>/<name>/SKILL.md` already exists, do not overwrite it (preserves post-migration edits).
2. **Extract Content & Metadata**:
   - Read the original `.md` content.
   - Extract title, purpose, and instructions.
3. **Format Frontmatter**:
   Ensure `name` and `description` are properly declared:

   ```markdown
   ---
   name: <name>
   description: <One-sentence clear summary of what the skill does and when to run it>.
   ---

   # <Workflow Title>

   <Preserved workflow instructions and commands>
   ```

4. **Write Target Skill**:
   - Create folder: `.agents/skills/<name>/`
   - Write: `.agents/skills/<name>/SKILL.md`

### Step 3: Safely Archive Legacy Workflow

Never delete the source workflow permanently without a backup:

- Rename the old file to `<name>.md.bak`.
- If `workflows.json` exists in `.agents/`, remove the corresponding entry.

### Step 4: Validate

- Verify the skill folder exists and is visible to Antigravity.
- Test typing `/<name>` to confirm slash command autocomplete.
