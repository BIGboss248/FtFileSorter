# Antigravity Lifecycle Hooks Guide (`hooks.json`)

Lifecycle hooks allow you to execute external shell commands or scripts at deterministic points during the agent's execution loop. Use hooks for command gating, security auditing, auto-linting, dynamic prompt injection, or preventing premature task exit.

---

## 1. File Location & Structure

Hooks are configured in `hooks.json`:

- **Workspace**: `<workspace_root>/.agents/hooks.json`
- **Global**: `~/.gemini/config/hooks.json`
- **Plugin**: `.agents/plugins/<plugin_name>/hooks.json`

Top-level structure maps arbitrary hook identifiers to event configurations:

```json
{
  "safety-guard": {
    "enabled": true,
    "PreToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          {
            "type": "command",
            "command": "python ./scripts/safety_gate.py",
            "timeout": 15
          }
        ]
      }
    ]
  },
  "task-watchdog": {
    "Stop": [
      {
        "type": "command",
        "command": "python ./scripts/stop_watchdog.py",
        "timeout": 10
      }
    ]
  }
}
```

---

## 2. Event Types & Matchers

| Event                | Firing Point                         | Matcher Required?     | Execution Structure            |
| :------------------- | :----------------------------------- | :-------------------- | :----------------------------- |
| **`PreToolUse`**     | Before a tool executes               | Yes (`matcher` regex) | Grouped inside `hooks` wrapper |
| **`PostToolUse`**    | Immediately after tool finishes      | Yes (`matcher` regex) | Grouped inside `hooks` wrapper |
| **`PreInvocation`**  | Before the model is called           | No                    | Flat array of handler objects  |
| **`PostInvocation`** | After model completes turn           | No                    | Flat array of handler objects  |
| **`Stop`**           | When execution loop is about to exit | No                    | Flat array of handler objects  |

### Matcher Syntax (for `PreToolUse` and `PostToolUse`):

- `"*"` or `""`: Matches any tool.
- `"run_command"`: Matches exact tool.
- `"run_command|write_to_file"`: Matches either tool.
- `"browser_.*"`: Regex prefix match.

---

## 3. Communication Protocol (stdin / stdout)

Hooks communicate exclusively through JSON over standard streams:

- **stdin**: Injected with the event payload JSON.
- **stdout**: Hook script must write its response JSON.
- **All payload keys are strictly camelCase** (e.g. `conversationId`, `stepIdx`, `toolCall`).

### Common Input Metadata (Provided to all hooks):

```json
{
  "conversationId": "ec33ebf9-0cba-4100-8142-c61503f6c587",
  "workspacePaths": ["/path/to/project"],
  "transcriptPath": "/path/to/transcript.jsonl",
  "artifactDirectoryPath": "/path/to/artifacts",
  "modelName": "auto"
}
```

---

## 4. Event Contracts & Payload Specifications

### 1. `PreToolUse` Contract

Intercept and inspect tool calls before they run.

**stdin Input**:

```json
{
  "toolCall": {
    "name": "run_command",
    "args": {
      "CommandLine": "git push --force"
    }
  },
  "stepIdx": 12,
  ... (common metadata)
}
```

**stdout Response**:

```json
{
  "decision": "ask",
  "reason": "Force push requires explicit user approval.",
  "overwrite": {
    "CommandLine": "git push --force-with-lease"
  }
}
```

- **`decision`**: `"allow"` (auto-run), `"deny"` (hard block), `"ask"` (prompt user), or `"force_ask"` (prompt user even if previously approved).
- **`overwrite`**: Shallow top-level object to overwrite tool arguments before execution.
- **`reason`**: Explanation displayed to user/agent.

---

### 2. `PostToolUse` Contract

Run post-execution formatting, linting, or telemetry.

**stdin Input**:

```json
{
  "stepIdx": 12,
  "error": "exit status 1",
  ... (common metadata)
}
```

**stdout Response**:
Must return an empty JSON object: `{}`.

---

### 3. `PreInvocation` Contract

Inject transient system messages or context before the model generates its next turn.

**stdin Input**:

```json
{
  "invocationNum": 2,
  "initialNumSteps": 8,
  ... (common metadata)
}
```

**stdout Response**:

```json
{
  "injectSteps": [
    {
      "ephemeralMessage": "Remember to run tests before completing this task."
    }
  ]
}
```

---

### 4. `PostInvocation` Contract

Inspect model outputs and control execution flow.

**stdout Response**:

```json
{
  "terminationBehavior": "force_continue"
}
```

- `terminationBehavior`: `"force_continue"` (forces another turn) or `"terminate"` (stops agent).

---

### 5. `Stop` Contract (Watchdog)

Inspect why the agent stopped and prevent premature termination if work remains undone.

**stdin Input**:

```json
{
  "executionNum": 1,
  "terminationReason": "model_stop",
  "error": "",
  "fullyIdle": true,
  ... (common metadata)
}
```

**stdout Response**:

```json
{
  "decision": "continue",
  "reason": "Test suite has not passed yet. Please run pnpm test and fix any errors."
}
```

- Set `decision: "continue"` to block stopping and send the agent back into the loop with `reason`.

---

## 5. Ready-to-Use Hook Implementation (Python)

Save this template to `.agents/scripts/safety_guard.py`:

```python
#!/usr/bin/env python3
import json
import sys

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input:
            print(json.dumps({"decision": "allow"}))
            return

        payload = json.loads(raw_input)
        tool_call = payload.get("toolCall", {})
        tool_name = tool_call.get("name", "")
        args = tool_call.get("args", {})

        # Check command safety
        if tool_name == "run_command":
            cmd = args.get("CommandLine", "")
            if "rm -rf /" in cmd or "DROP DATABASE" in cmd:
                print(json.dumps({
                    "decision": "deny",
                    "reason": "Dangerous destructive command blocked by safety hook."
                }))
                return

        # Default allow
        print(json.dumps({"decision": "allow"}))
    except Exception as e:
        # Fallback safely
        print(json.dumps({"decision": "ask", "reason": f"Hook error: {str(e)}"}))

if __name__ == "__main__":
    main()
```
