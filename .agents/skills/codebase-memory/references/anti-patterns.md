# Codebase Memory Guardrails & Anti-Patterns

This reference highlights common agent mistakes when navigating code and the required operational standards.

---

## Anti-Patterns & Operational Standards

| Anti-Pattern | Correct Operational Standard |
| :--- | :--- |
| **Searching without checking index freshness** | Always call `index_repository(mode: "fast")` or verify with `index_status` first, since background auto-watch is disabled. |
| **Using `grep` to find function definitions** | Call `search_graph` with the symbol name; it returns qualified names, exact file paths, line ranges, and caller counts. |
| **Reading 1000 lines of a file to see 1 function** | Call `get_code_snippet` with the symbol's `qualified_name` to retrieve only the relevant declaration. |
| **Manually reading every file to find callers** | Call `trace_path` with `direction: "inbound"` to trace all dependent callers across the repo. |
| **Assuming graph is 100% complete** | Graph is best-effort. If `index_status` lists files under `parse_partial`, use text grep for those specific flagged line ranges. |
| **Enabling `auto_watch`** | Never enable `auto_watch`; keep it `false` in `.cbmignore` / config to prevent system stutters during file editing. |

