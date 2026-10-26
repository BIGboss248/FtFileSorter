# GitHub MCP & CLI Integration Guide

This reference provides the technical invocation patterns for interacting with GitHub Issues during triage operations.

---

## 1. Primary Method: GitHub MCP Server (`github-mcp-server`)

The `github-mcp-server` is configured in the workspace and provides structured, programmatic tools.

### 1.1. Check for Duplicate Issues
Before creating a new bug report, search for existing issues to prevent duplicates:

```json
Tool: call_mcp_tool
ServerName: github-mcp-server
ToolName: search_issues
Arguments: {
  "q": "repo:OWNER/REPO is:issue is:open cart hydration mismatch",
  "per_page": 5
}
```

### 1.2. Create Issue
When creating an issue, always format the title as conventional commit (`fix(<scope>): <description>`) and attach relevant labels:

```json
Tool: call_mcp_tool
ServerName: github-mcp-server
ToolName: issue_write
Arguments: {
  "method": "create",
  "owner": "OWNER",
  "repo": "REPO",
  "title": "fix(cart): hydration mismatch on cart drawer rehydrate",
  "body": "### Description\nCart drawer fails during client rehydration.\n\n### Error\n```\nText content does not match server-rendered HTML\n```\n\n### Repro Steps\n1. Add item to cart\n2. Reload page",
  "labels": ["bug", "agent-triage"]
}
```

### 1.3. Post Diagnostic Comment
Log the root cause analysis directly on the issue:

```json
Tool: call_mcp_tool
ServerName: github-mcp-server
ToolName: add_issue_comment
Arguments: {
  "owner": "OWNER",
  "repo": "REPO",
  "issue_number": 24,
  "body": "### 🔍 Automated Triage: Investigation & Diagnosis\n\n**Root Cause:** Synchronous access to `localStorage` during initial render.\n**Affected File:** `app/components/CartDrawer.tsx`\n**Plan:** Guard access inside `useEffect` or `useSyncExternalStore`."
}
```

### 1.4. Close Issue with Resolution
Always set `state_reason: "completed"` when closing resolved issues:

```json
Tool: call_mcp_tool
ServerName: github-mcp-server
ToolName: issue_write
Arguments: {
  "method": "update",
  "owner": "OWNER",
  "repo": "REPO",
  "issue_number": 24,
  "state": "closed",
  "state_reason": "completed"
}
```

---

## 2. Fallback Method: GitHub CLI (`gh`) & Helper Script

If the MCP server is unreachable or offline, the agent executes commands via `gh` CLI directly or via `scripts/triage_issue.ps1`.

### 2.1. Via `triage_issue.ps1`
- **Search:**
  ```powershell
  pwsh .agents/skills/github-triage/scripts/triage_issue.ps1 -Action search -Title "cart hydration"
  ```
- **Create:**
  ```powershell
  pwsh .agents/skills/github-triage/scripts/triage_issue.ps1 -Action create -Title "fix(cart): hydration mismatch" -Body "..." -Labels "bug,agent-triage"
  ```
- **Comment:**
  ```powershell
  pwsh .agents/skills/github-triage/scripts/triage_issue.ps1 -Action comment -IssueNumber 24 -Body "Root cause diagnosed..."
  ```
- **Close:**
  ```powershell
  pwsh .agents/skills/github-triage/scripts/triage_issue.ps1 -Action close -IssueNumber 24 -Body "Verified by tests. Closes #24."
  ```

### 2.2. Via Native `gh` Commands
```powershell
# Create issue
gh issue create --title "fix(cart): hydration mismatch" --body "..." --label "bug,agent-triage"

# Add comment
gh issue comment 24 --body "..."

# Close issue
gh issue close 24 --reason completed --comment "..."
```
