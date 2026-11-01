---
description: Run the read-only reviewer on a diff, path, or the whole change set
agent: reviewer
---

Review the current change set: commits against the base branch named in
`AGENTS.md`, the working tree (`git diff HEAD`), and untracked files
(`git ls-files --others --exclude-standard`).

Target (leave empty for the whole change set): $ARGUMENTS

Use the report standard at `.agents/rules/code-review-report.md`. Return only
the report.
