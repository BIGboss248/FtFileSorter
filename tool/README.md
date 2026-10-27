# Command-line tools

Standalone Dart entry points that reuse the application's services without
starting the Flutter UI.

| Tool | Purpose |
| --- | --- |
| `index_folder.dart` | Index a folder tree to CSV and optionally copy files into a destination, sorted by document code. |

Run the tools from the repository root:

```bat
dart run tool/index_folder.dart <folder> [output.csv] [options]
```

## index_folder.dart

Scans a folder, extracts the document code and document type from every file
name, writes the same CSV the **File Indexer** screen exports, and can copy the
files into a destination folder.

### Arguments

| Argument | Required | Description |
| --- | --- | --- |
| `<folder>` | Yes | Folder to index. |
| `[output.csv]` | No | CSV destination. Defaults to `file_index.csv` inside `<folder>`. |

### Options

| Option | Description |
| --- | --- |
| `--no-recursive` | Only index the direct children of `<folder>`. Nested folders are skipped. |
| `--copy-by-code=<destination>` | Copy **every** indexed file into `<destination>`, sorted by document code (see below). |
| `--copy-duplicates=<destination>` | Legacy mode: copy only files whose code is shared with at least one other file, into `<destination>/<code>/`. |
| `--overwrite-duplicates` | Replace files that already exist in the destination. Applies to both copy modes. |

Copy options may be written with or without `=`. Without `=`, the next argument
is used as the destination:

```bat
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted"
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code="D:\Sorted"
```

`--copy-by-code` and `--copy-duplicates` cannot be combined.

### How files are sorted (`--copy-by-code`)

The document code is the **first 18 characters** of the file name, ignoring the
extension and uppercased. Files are placed like this:

| Situation | Destination |
| --- | --- |
| Complete code shared by **two or more** files | `<destination>/<code>/` (one folder per code) |
| Complete code belonging to **exactly one** file | `<destination>/` directly — no folder is created for it |
| Name shorter than 18 characters (no complete code) | `<destination>/no_code/` |

Example source:

```text
AS BUILT/
├─ DWG/DNSSGM12000JCSS70001-0001.dwg
├─ PDF/DNSSGM12000JCSS70001-0001.pdf
├─ MISC/DNSSGH13900JACD00100-0001.pdf
└─ MISC/T2404.pdf
```

Result of `--copy-by-code "D:\Sorted"`:

```text
D:\Sorted/
├─ DNSSGM12000JCSS700/                    <- code shared by two files
│  ├─ DNSSGM12000JCSS70001-0001.dwg
│  └─ DNSSGM12000JCSS70001-0001.pdf
├─ DNSSGH13900JACD00100-0001.pdf          <- unique code, copied loose
└─ no_code/
   └─ T2404.pdf                           <- name has no complete code
```

### Copy rules

- Source files are **copied**, never moved or deleted.
- Missing destination folders are created automatically.
- Existing destination files are kept by default. Use
  `--overwrite-duplicates` to replace them.
- Re-running a copy is idempotent: a destination file with the same size as its
  source is treated as already copied and skipped.
- Two source files with the same name inside one code folder are both kept; the
  later ones get ` (2)`, ` (3)`, ... before the extension.
- Files with a complete code appear exactly once in the destination: in their
  code folder when the code is shared, or loose in the destination when it is
  unique.
- Use a destination outside the indexed folder, otherwise the copies will be
  picked up by the next index run.

### Document type

For reference, characters 12 and 13 of the file name form the two-letter
document type (for example `JC` in `DNSSGM12000JCSS70001-0001.dwg`). It is
written to the CSV but does not affect the copy layout.

### Examples

```bat
:: Index only, CSV next to the scanned folder
dart run tool/index_folder.dart "D:\Documents\AS BUILT"

:: Index only, explicit CSV path, root folder only
dart run tool/index_folder.dart "D:\Documents\AS BUILT" "D:\exports\index.csv" --no-recursive

:: Sort every file by document code
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT"

:: Re-run a sort and replace files that are already in the destination
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --overwrite-duplicates

:: Copy duplicate document codes only (legacy mode)
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-duplicates "D:\Duplicate Codes"
```

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Index and any requested copy finished. Individual copy warnings may still be printed. |
| `1` | Indexing failed, or every requested copy failed. |
| `64` | Invalid arguments (usage error). |

### Notes

- The **File Indexer** screen uses the same indexing service and offers the
  duplicate-only copy mode through its "Copy duplicate document codes" switch.
  Files are chosen at runtime there, so the sort-everything mode is currently
  CLI-only.
- Debug logging is printed to the console for every indexed and copied file.
