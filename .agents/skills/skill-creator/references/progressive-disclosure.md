# Progressive Disclosure & Context Management

Progressive disclosure is an architectural pattern that keeps AI agents fast, precise, and cost-effective by loading instructions and documentation **only when needed**.

---

## 1. Why Progressive Disclosure Matters

- **Context Window Conservation**: Even with large context windows (1M+ tokens), dumping large documentation sets into system prompts causes "needle in a haystack" degradation, increasing hallucinations and instruction drift.
- **Speed & Latency**: Shorter prompts process significantly faster and cost less.
- **Modularity**: Sub-topics can be updated independently without rewriting the primary runbook.

---

## 2. Directory Separation Strategy & 4-Layer Architecture

Organize your skill repository cleanly across these modular layers:

```text
skills/<skill-name>/
├── SKILL.md                 # Layer 1: Core Orchestrator Runbook (<150–250 lines)
├── references/              # Layer 2: Deep Technical Manuals & Rule Matrices (<100–200 lines each)
│   ├── api-reference.md
│   └── error-handbook.md
├── resources/               # Layer 3: Templates, Configs, Schemas, & Boilerplates
│   └── templates/
│       ├── config.example.json
│       └── Component.template.tsx
├── examples/                # Layer 3: Complete Working Code Snippets & Case Studies
│   └── good-patterns.ts
└── scripts/                 # Layer 4: Deterministic Cross-Platform CLI Helpers
    ├── run_checks.ps1       # Windows PowerShell
    └── run_checks.sh        # Linux / macOS Bash
```

---

## 3. How to Structure `SKILL.md` (Layer 1: Orchestrator)

The main `SKILL.md` is an **orchestration runbook and high-level checklist**, NOT an encyclopedia or code dump:

- **Target Size**: Under 150–250 lines.
- **Strictly No Large Inline Code Fences**: Never paste entire 50+ line configuration files, component boilerplates, or scripts directly into `SKILL.md`.
- **Reference & Scaffold Pattern**: Link to template files and specify where to copy/scaffold them:

  ```markdown
  ### Step 3: Scaffold Test Configuration

  1. Inspect the starter configuration in [jest.config.template.ts](file:///resources/templates/jest.config.template.ts).
  2. Write the configuration to root `jest.config.ts`, customizing the path aliases if detected.
  3. If troubleshooting mocking errors, read [mocking-guide.md](file:///references/mocking-guide.md).
  ```

---

## 4. Offloading Code Templates & Boilerplates (`resources/templates/` & `examples/`)

### Why Offload Code Templates?

1. **Context Window Protection**: Pushing 300 lines of template code into `SKILL.md` wastes agent attention on syntax that may not even be needed for the active task step.
2. **Deterministic File Operations**: By storing templates as standalone files, agents can use native file-copying operations or view them on demand rather than generating code from memory.
3. **Syntax Validation & Formatting**: Template files can be formatted with Prettier/ESLint directly.

### Best Practices for Templates:

- Place boilerplate files under `resources/templates/` (e.g. `resources/templates/docker-compose.prod.yml`).
- Use `.template` or standard extensions (e.g. `Component.template.tsx`, `nginx.conf`).
- Place working reference implementations under `examples/` (e.g. `examples/custom-hook-usage.tsx`).
- In `SKILL.md` or `references/*.md`, reference templates using standard markdown links.

---

## 5. Authoring Guidelines for `references/` (Layer 2)

- **Single-Topic Focus**: Keep each reference file dedicated to one specific topic (e.g. `caching-rules.md`, `database-schema.md`, `error-recovery.md`).
- **Target Size**: 50–200 lines per file.
- **Concise Tables & Bullet Points**: Prefer structured tables and short checklists over long paragraphs.
- **No Redundancy**: Avoid repeating instructions already stated in `SKILL.md`.

---

## 6. Script Design Guidelines (`scripts/` - Layer 4)

- Provide native scripts for both major environments: `.ps1` for PowerShell (Windows) and `.sh` for POSIX shells (Linux/macOS).
- Always support a `-Help` / `--help` flag explaining inputs and expected outputs.
- Write self-contained scripts or clearly fail early with human-readable error messages if dependencies are missing.
- Ensure scripts return standard exit codes (`0` for success, non-zero for error) so agents can interpret task status unambiguously.
