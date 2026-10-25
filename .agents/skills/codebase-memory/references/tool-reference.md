# Codebase Memory MCP Tool Reference Matrix

This reference details the full parameter schemas and operational options for the codebase-memory MCP server tools.

---

## Tool Reference Matrix

| Capability | Tool Name | Required Parameters | Key Optional Parameters | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Verify Status** | `index_status` | `project` | N/A | Returns indexed file count, symbol count, and partial parse errors. |
| **Trigger Indexing** | `index_repository` | `repo_path` | `mode` (`"fast"`, `"moderate"`, `"full"`), `persistence` | Indexes or refreshes the repository knowledge graph. |
| **List Projects** | `list_projects` | None | N/A | Lists all indexed projects in the local SQLite knowledge base. |
| **Search Symbols** | `search_graph` | `project` | `query`, `name_pattern`, `semantic_query`, `limit`, `offset` | BM25 + semantic vector structural search across symbols and routes. |
| **Trace Call Chain** | `trace_path` | `project`, `function_name` | `direction` (`"inbound"`, `"outbound"`, `"both"`), `depth`, `mode` | Resolves multi-hop callers and callees in the knowledge graph. |
| **Retrieve Source** | `get_code_snippet` | `project`, `qualified_name` | `include_neighbors` | Fetches exact symbol source code with line ranges and caller count. |
| **Blast Radius** | `detect_changes` | `project` | `base_branch`, `since`, `scope` (`"impact"`, `"files"`), `depth` | Maps git diff changes to their transitive blast radius and impact set. |
| **Architecture** | `get_architecture` | `project` | `aspects` (`["hub_nodes"]`, `["layers"]`, `["all"]`) | Identifies high-centrality components, hub modules, and system layers. |
| **Literal Text** | `search_code` | `project`, `query` | `file_pattern`, `case_sensitive`, `limit` | Fallback text search for non-code files (markdown, CSS, JSON). |

