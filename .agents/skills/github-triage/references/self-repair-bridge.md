# Self-Repair Bridge (`autofix.json` Integration)

This document specifies the contract between the `github-triage` skill and the `self-repair` learning engine.

---

## 1. Two-Tier Memory Architecture

| Attribute | Macro Layer (GitHub Issues) | Micro Layer (`autofix.json`) |
|---|---|---|
| **Location** | GitHub Remote Repository | `.agents/autofix.json` |
| **Audience** | Humans, Team Members, CI/CD, Agent | Local Agent Pre-Task Scanner |
| **Content** | Full stack traces, screenshots, reproduction steps, fix diffs | Imperative constraint rule (`"Never X; always Y"`) |
| **Purpose** | Historical audit trail, collaboration, searchability | Instant pre-task guardrail to prevent repeat mistakes |

---

## 2. Rule Extraction Protocol

When closing a resolved GitHub Issue, the agent must extract an imperative rule to guarantee that the same mistake is never repeated in future sessions:

1. **Identify the Anti-Pattern**: What code pattern, configuration, or assumption caused the bug?
2. **Formulate the Imperative Rule**:
   - Begin with an imperative verb (`"Always..."`, `"Never..."`, `"Ensure..."`).
   - State the forbidden behavior and the required alternative.
   - Do not reference temporary task details; formulate a generalizable architectural or coding rule.
3. **Select Valid Category**:
   - `[STYLE]`: Formatting, naming conventions, import ordering.
   - `[CODE]`: Language patterns, type definitions, error handling, React patterns.
   - `[ARCH]`: Project structure, boundaries, layer constraints.
   - `[TOOL]`: CLI tools, build runners, test flags.
   - `[PROCESS]`: Git workflows, release requirements.
   - `[DATA]`: Database models, state shapes, serialization.
   - `[UX]`: UI accessibility, visual behaviors.
4. **Append to `.agents/autofix.json`**:
   Ensure sequential `Rule_number` increment and include `"Issue": "#N"`.

---

## 3. JSON Schema Contract

```json
[
  {
    "Rule_number": 12,
    "Category": "CODE",
    "Instruction": "Never access browser-only globals (like localStorage or window) during initial React server/client render; always isolate inside useEffect or useSyncExternalStore with client fallbacks.",
    "Why": "Eliminated hydration mismatch crash reported and resolved in GitHub Issue #24.",
    "Issue": "#24"
  }
]
```
