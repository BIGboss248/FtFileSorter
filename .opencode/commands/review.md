---
description: Run the read-only reviewer on a diff, path, or the working tree
agent: reviewer
---

Review $ARGUMENTS.

If no target is given above, review the full change set: branch commits against
the base branch named in `AGENTS.md`, the working tree (`git diff HEAD`), and
untracked files (`git ls-files --others --exclude-standard`).

Use the report standard at `.agents/rules/code-review-report.md`. Return only
the report.
