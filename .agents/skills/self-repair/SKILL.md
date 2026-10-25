---
name: self-repair
description: >
  Self-correcting rules engine and feedback loop that learns from user corrections, mistakes, and project-specific constraints by maintaining a persistent autofix ruleset. Scans learned rules before starting any task, resolves conflicts, and automatically appends new rules upon corrections. Triggers on user corrections ("no, do it this way", "never do X", "always use Y"), /learn, "self repair", "add rule", "update rules", or when diagnosing assumptions and bugs.
  CRITICAL ALWAYS-ACTIVE LIFECYCLE SKILL. Must always be kept in context, loaded at session start, and consulted before starting ANY task to read and apply active constraints from autofix.json. MUST ALWAYS be triggered immediately whenever the user provides ANY correction, preference, criticism, rejection of an approach, or adjustment ("no", "don't do X", "use Y", "remember", "prefer"), or when any mistake/bug is identified. Automatically and immediately formulates and appends the new imperative rule to the project's autofix.json ruleset file.
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, AskUserQuestion
---

# Self-Repair (Self-Correcting Rules Engine)

A self-correcting memory and learning engine that records corrections, project conventions, and bug fixes into a persistent ruleset file (`autofix.json`). It ensures the agent continuously adapts, eliminates repeat mistakes across sessions, and adheres strictly to user preferences.

**Why this works:** AI agents tend to repeat the same default assumptions or stylistic errors across fresh sessions. By externalizing learned knowledge into an imperative, versioned JSON ruleset with strict precedence (newer rules win), the agent retains hard boundaries tailored to the specific user and repository.

---

## Storage & Configuration

The skill looks for the ruleset file in one of the following locations (in order of priority):

1. `.agents/autofix.json`
2. `autofix.json` (at workspace root)
3. `.rules/autofix.json`

If none exists when a new rule needs to be added, it creates `.agents/autofix.json` (or root `autofix.json` depending on project convention).

### Rule Schema

Each rule is stored inside a JSON array with the following schema:

```json
[
  {
    "Rule_number": 1,
    "Category": "CODE",
    "Instruction": "Never use default exports for React components - always use named exports.",
    "Why": "Ensures consistency with the codebase and simplifies refactoring."
  }
]
```

### Allowed Categories

| Category    | Description                                                          | Examples                                                            |
| ----------- | -------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `[STYLE]`   | Code formatting, naming conventions, import ordering, comments       | "Always use camelCase for helper functions"                         |
| `[CODE]`    | Language patterns, library choices, type definitions, error handling | "Never use `any` in TypeScript; use `unknown` with type guards"     |
| `[ARCH]`    | Directory structure, module boundaries, architectural layers         | "API routes live in `src/server/routes/`, not `src/api/`"           |
| `[TOOL]`    | CLI commands, build tools, package managers, testing frameworks      | "Always use `pnpm` instead of `npm` or `yarn`"                      |
| `[PROCESS]` | Git workflow, commit messages, PR requirements, test gates           | "Never add emojis to commit messages"                               |
| `[DATA]`    | Database schemas, migrations, caching strategies, state shapes       | "Always include `created_at` and `updated_at` timestamps on tables" |
| `[UX]`      | UI behaviors, copy conventions, accessibility standards              | "Always provide an explicit `aria-label` for icon-only buttons"     |
| `[OTHER]`   | General project or domain-specific preferences                       | "Always document public API endpoints in markdown table format"     |

---

## Operational Workflow

```
[Session Start / Task Received]
            │
            ▼
┌───────────────────────────────┐
│ 1. Pre-Task Scan              │ ◄── Read autofix.json
│    - Load all rules           │
│    - Resolve conflicts (new>old)
│    - Build active constraints │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│ 2. Task Execution             │
│    - Apply constraints        │
│    - Execute code / edits     │
└───────────┬───────────────────┘
            │
            ├─────────────────────────────────────────┐
            │                                         │
     [No Corrections]                         [Trigger Detected]
            │                                         │
            ▼                                         ▼
┌───────────────────────────────┐       ┌───────────────────────────────┐
│ Task Complete                 │       │ 3. Self-Repair & Capture      │
│ Deliver output to user        │       │    - Formulate imperative rule│
└───────────────────────────────┘       │    - Append to autofix.json   │
                                        │    - Acknowledge learning     │
                                        └─────────────┬─────────────────┘
                                                      │
                                                      ▼
                                        ┌───────────────────────────────┐
                                        │ 4. Re-execute & Correct       │
                                        │ Fix current task output       │
                                        └───────────────────────────────┘
```

---

## Detailed Step-by-Step Execution

### 1. Pre-Task Scan (Before Doing Anything)

Before planning or modifying files in any task:

1. **Locate and load `autofix.json`**.
2. **Scan the rules**:
   - Check if any rule directly applies to the files, tools, or patterns involved in the current prompt.
3. **Resolve conflicts**:
   - If two rules give conflicting guidance, the **higher-numbered (newer) rule wins**.
4. **Hold constraints active**:
   - Treat all active rules as hard constraints (equivalent to prompt contract `CONSTRAINTS`).

---

### 2. When to Add a Rule (Trigger Conditions)

Immediately trigger rule capture when any of the following happens:

- **User explicitly corrects output**: e.g., _"No, don't use X, do it with Y"_, _"We don't use class components here"_.
- **User rejects a file, approach, or pattern**: e.g., _"Don't put test files next to source code"_.
- **User states a personal/team preference**: e.g., _"Always format commit messages as Conventional Commits"_, _"Never use emojis in docs"_.
- **A bug was caused by wrong assumptions**: Agent assumed a library or file location that caused a failure.
- **User runs `/learn` or asks to remember a rule**.

---

### 3. Appending a New Rule

When a trigger occurs, perform the following atomic update:

1. Read the existing `autofix.json` array.
2. Determine the next sequential `Rule_number`:
   - If the highest existing rule number is $N$, the new rule is $N + 1$.
   - If the file is empty or new, start at `1`.
3. Format the new rule object:
   - **Rule_number**: Sequential integer.
   - **Category**: One of the standard categories (`STYLE`, `CODE`, `ARCH`, `TOOL`, `PROCESS`, `DATA`, `UX`, `OTHER`).
   - **Instruction**: Written in strict imperative format: `"Never/Always do X - because Y."`
   - **Why**: Brief reason (e.g. _"user preference"_, _"codebase pattern"_, _"framework limitation"_).
4. Append the rule into the JSON array and save the file formatted with 2-space indentation.
5. **Deduplicate & Consolidate**: Merge overlapping or superseded rules in the same domain and keep `Rule_number` sequentially ordered (`1..N`) so `autofix.json` stays free of duplicates. When any skill in `.agents/skills/` is updated, sync it to `d:/Scripts/Obsidian/skills/` and commit and push the synced changes inside the `d:/Scripts/Obsidian` repository only.
6. Briefly notify the user:
   > _"Learned rule #`<N>` (`[CATEGORY]`): `<Instruction>` — recorded in `autofix.json`."_

---

### 4. Example Rules File (`autofix.json`)

```json
[
  {
    "Rule_number": 1,
    "Category": "PROCESS",
    "Instruction": "Never add emojis to commit messages - keep commit titles plain Conventional Commits.",
    "Why": "user preference"
  },
  {
    "Rule_number": 2,
    "Category": "ARCH",
    "Instruction": "Always place API route handlers in 'src/server/routes/', never in 'src/api/' - maintain consistent backend architecture.",
    "Why": "existing codebase pattern"
  },
  {
    "Rule_number": 3,
    "Category": "CODE",
    "Instruction": "Always use Zod schemas for input validation on all external entry points - prevent untyped runtime inputs.",
    "Why": "prevents runtime errors and enforces types"
  }
]
```

---

## Best Practices & Edge Cases

- **Atomic JSON Writing**: Always parse the existing JSON array, append the new object, and write back valid JSON. Never corrupt the file with unescaped text.
- **Concrete & Imperative**: Write rules that another AI can follow unambiguously. Avoid vague advice like _"Write clean code"_; prefer _"Always export types alongside component implementations in `.types.ts` files"_.
- **No Infinite Loops**: When recording a rule, do not trigger a separate self-repair loop for the rule file itself.
- **Superseding Rules**: If Rule 1 says _"Use Axios"_ and the user later instructs _"Migrate everything to Fetch"_, add Rule 4 _"Always use native Fetch instead of Axios"_ with `Why: "user requested migration to native fetch (supersedes Rule 1)"`.
