# AI Skill Templates & Boilerplates

Use these ready-to-use templates as starting points for common types of AI skills. Notice how all templates maintain **lean descriptions (<150–200 chars)** and offload deep code blocks and boilerplates to `resources/templates/` and `references/`.

---

## 1. Workflow / Setup Runbook Skill Template

Best for multi-step tasks like deployment, migrations, setups, or audits.

```markdown
---
name: service-migration
description: >-
  Migrate database tables and services to schema v2. Use when running
  schema migrations, upgrading models, or executing database transitions.
---

# Service Migration Skill

Step-by-step orchestrator for executing database schema and service migrations safely.

## Prerequisites & Checklist

- [ ] Database credentials configured in `.env.local`
- [ ] Working branch created (`git checkout -b chore/migrate-schema`)

## Step-by-Step Procedure

### 1. Pre-Migration Audit

1. Run the audit script:
   `powershell -ExecutionPolicy Bypass -File ./scripts/audit_schema.ps1`
2. Review audit logs in `logs/audit.json`. For audit error codes, consult [audit-codes.md](file:///references/audit-codes.md).

### 2. Scaffold Migration Scripts

1. Inspect the migration boilerplate in [migration.template.ts](file:///resources/templates/migration.template.ts).
2. Generate the migration file under `src/migrations/`.

### 3. Apply Migrations

1. Run the migration command: `pnpm run migrate:v2`
2. Validate foreign key constraints.

## Edge Cases & Pitfalls

For complex locking considerations and zero-downtime strategies, read [concurrency-guide.md](file:///references/concurrency-guide.md).

## Verification & Self-Check

- [ ] Run test suite: `pnpm test:integration`
- [ ] Verify healthcheck endpoint returns 200 OK.
```

---

## 2. Tool / CLI Wrapper Skill Template

Best for teaching an agent how to use a specific CLI tool or library (e.g. Docker, Android CLI, Stitch).

```markdown
---
name: cli-tool-helper
description: >-
  Automate workflows with MyTool CLI. Use when running MyTool commands,
  troubleshooting CLI flags, or configuring tool options.
---

# MyTool CLI Helper

Runbook for invoking `mytool` commands safely and accurately.

## Command Reference Matrix

| Goal          | Command        | Flags / Options          |
| :------------ | :------------- | :----------------------- |
| Build release | `mytool build` | `--release --minify`     |
| Run linter    | `mytool lint`  | `--fix --max-warnings=0` |

## Execution Guidelines

1. Always run commands using single, isolated operations.
2. Check tool exit code. If non-zero, consult [troubleshooting.md](file:///references/troubleshooting.md).
3. Format output following the schema in [output-schema.json](file:///resources/templates/output-schema.json).
```

---

## 3. Architecture & Review Skill Template

Best for design review, spec-driven development, code quality audits, or security inspections.

```markdown
---
name: security-audit
description: >-
  Audit code for security vulnerabilities, secrets, and auth issues. Use
  when reviewing PRs for security or conducting application security audits.
---

# Security Audit Skill

Guide for conducting comprehensive application security reviews.

## Top Vulnerability Vectors to Inspect

1. **Exposed Credentials**: Verify no `.env` files or secrets are committed.
2. **Missing Auth Middleware**: Ensure all private routes check session tokens.
3. **Database RLS / Permissions**: Verify Row Level Security is enabled.
4. **Input Sanitization**: Ensure user inputs are validated before database queries.

## Review Workflow

1. Scan touched files for vulnerability vectors.
2. Format findings using the report template in [security-report.template.md](file:///resources/templates/security-report.template.md).
3. If remediation patterns are needed, consult [remediation-patterns.md](file:///references/remediation-patterns.md).
```
