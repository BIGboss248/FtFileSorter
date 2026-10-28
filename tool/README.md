# Command-line tools

Standalone Dart entry points that reuse the application's services without
starting the Flutter UI.

| Tool | Purpose |
| --- | --- |
| `index_folder.dart` | Index a folder tree to CSV, then optionally copy files into a destination, sorted by document code. |

Run the tools from the repository root:

```bat
dart run tool/index_folder.dart <folder> [output.csv] [options]
```

## Bundled Windows build

The Windows app can ship the CLI next to the GUI so both use the same shared
configuration and the user needs no Dart SDK. Build both with:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

This runs `flutter build windows --release`, then compiles this tool into
`build\windows\x64\runner\Release\index_folder.exe` with `dart compile exe`. The
Release folder then contains:

```text
build\windows\x64\runner\Release\
├─ ft_file_sorter.exe   <- GUI
├─ index_folder.exe     <- CLI (self-contained, no Dart SDK required)
├─ flutter_windows.dll
└─ data\
```

Pass `-Installer` to also build the Inno Setup installer, which installs both
executables side by side:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Installer -Version 1.2.3
```

The installer offers an optional task that adds the install folder to the user
`PATH`, so `index_folder` can be run from any terminal.

Both executables resolve the shared rules through
`%APPDATA%\FtFileSorter\allowed_types.json`, so the document-type rules edited in
the GUI's **File Type Rules** dialog are exactly the ones the CLI applies. The
rule path is independent of the working directory, so the GUI and CLI cannot
drift to different configuration files.

## index_folder.dart

The tool runs in four phases:

1. **Index** — scans `<folder>`, extracts the document code and document type
   from every file name, and writes a CSV.
2. **Copy** (optional) — when `--copy-by-code` or `--copy-duplicates` is given,
   copies the files into the chosen destination and rewrites the same CSV with a
   `Copied To` column showing where each file was copied.
3. **Cleanup** (optional) — when `--allowed-types` is given (or the shared rules
   file has rules), copied files whose extension is not allowed for their
   document type are moved into `<destination>/trash/`, and the CSV is updated
   with their final paths.
4. **Flatten** (optional) — when `--flatten-single-file-folders` is given,
   destination subfolders that hold exactly one file are collapsed: the file is
   moved into the destination root, the empty folder is deleted, and the CSV is
   updated with the new paths.

The final CSV is also copied into the copy destination itself, so each sorted
folder carries its own index snapshot.

### Arguments

| Argument | Required | Description |
| --- | --- | --- |
| `<folder>` | Yes | Folder to index. |
| `[output.csv]` | No | Where to save the CSV. Defaults to `file_index.csv` inside `<folder>`. Use `--csv=<path>` instead when the argument order is inconvenient. |

### Options

| Option | Description |
| --- | --- |
| `--csv=<path>` | Save the CSV to `<path>`. Overrides `[output.csv]`. |
| `--no-recursive` | Only index the direct children of `<folder>`. |
| `--copy-by-code=<destination>` | Copy **every** indexed file into `<destination>`, sorted by document code (see below). |
| `--copy-duplicates=<destination>` | Legacy mode: copy only files whose code is shared with at least one other file, into `<destination>/<code>/`. |
| `--overwrite-duplicates` | Replace files that already exist in the destination. Applies to both copy modes. |
| `--allowed-types=<rules>` | Clean the copy: keep only the listed extensions per document type and move the rest into `<destination>/trash/`. See [Trash cleanup](#trash-cleanup---allowed-types). Repeatable. |
| `--allowed-types-file=<file>` | Load the cleanup rules from a JSON file. When neither this nor `--allowed-types` is given, the shared rules file edited in the app (`%APPDATA%\FtFileSorter\allowed_types.json`) is loaded automatically. |
| `--flatten-single-file-folders` | After copying and cleanup, move the only file of each destination subfolder into the destination root and delete the empty folder. Requires a copy mode. The `trash` folder is never flattened. |
| `--reindex` | Index again even when a CSV already exists. |
| `--reuse-index` | Reuse an existing CSV without asking. |
| `--recopy` | Copy again even when the destination already has a copy. |
| `--yes`, `-y` | Answer yes to the index and copy prompts. |
| `--help`, `-h` | Show the built-in usage text. |

Value options may be written with or without `=`. Without `=`, the next argument
is the value:

```bat
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted"
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv"
```

`--copy-by-code` and `--copy-duplicates` cannot be combined, and neither can
`--reindex` with `--reuse-index`. `--flatten-single-file-folders` requires
`--copy-by-code` or `--copy-duplicates`.

### Choosing where the CSV is saved

Three equivalent ways:

```bat
:: Second positional argument
dart run tool/index_folder.dart "D:\Documents\AS BUILT" "D:\exports\index.csv"

:: Explicit flag
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv="D:\exports\index.csv"

:: Default: file_index.csv inside the indexed folder
dart run tool/index_folder.dart "D:\Documents\AS BUILT"
```

The parent folder is created when it does not exist.

### The `Copied To` column

The CSV ends with a `Copied To` column. After a copy run, each row shows the
final path of that file — the copy folder, or `<destination>/trash/...` when the
cleanup step moved it:

```text
Index,File Name,...,Full Path,Size (Bytes),Modified,Copied To
1,DNSSGM12000JCSS70001-0001.dwg,...,D:\Docs\AS BUILT\DWG\DNSSGM12000JCSS70001-0001.dwg,2048,...,D:\Sorted\DNSSGM12000JCSS700\DNSSGM12000JCSS70001-0001.dwg
2,T2404.pdf,...,D:\Docs\AS BUILT\T2404.pdf,1024,...,D:\Sorted\no_code\T2404.pdf
```

- Files outside the copy mode (for example unique codes in
  `--copy-duplicates` mode) keep the column empty.
- A new copy run rebuilds the column from that run, so destinations from an
  older copy folder are not mixed in.
- Files that were already present in the destination with the same size are
  recorded too, because the tool knows where they live.
- A failed copy leaves the column empty and prints a warning.
- When `--allowed-types` moves a file to the trash, the column is updated to its
  final path inside `<destination>/trash/`.
- Re-indexing preserves destinations from the previous CSV for files that still
  exist. A completely new CSV starts with an empty column.

Because the copy step runs after indexing, the CSV is written up to four times
in a copy run: once right after the index (so the index exists even if copying
fails), again with the copy destinations, once more when the cleanup step moves
files to the trash, and again when flattened files change location.

When a copy destination is used, the final CSV is also written to
`<destination>/<csv file name>` (for example `D:\Sorted\index.csv`), including
when the copy was skipped or failed. The snapshot uses the same name as the
chosen CSV; if the CSV already lives in the destination, nothing is duplicated.

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

`--copy-duplicates` uses only the first two rules and ignores unique codes and
names without a complete code.

### Copy rules

- Source files are **copied**, never moved or deleted.
- Missing destination folders are created automatically.
- Existing destination files are kept by default. Use
  `--overwrite-duplicates` to replace them.
- Re-running a copy is idempotent: a destination file with the same size as its
  source is treated as already copied and skipped.
- Two source files with the same name inside one code folder are both kept; the
  later ones get ` (2)`, ` (3)`, ... before the extension.
- Use a destination outside the indexed folder, otherwise the copies will be
  picked up by the next index run.

### Trash cleanup (`--allowed-types`)

Some document types only need certain file formats (for example drawings that
should keep DWG and PDF, but not DXF). Pass a rule string, a rules file, or use
the shared rules edited in the app (see
[Rules file and the app editor](#rules-file-and-the-app-editor)):

```bat
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --allowed-types="JC=dwg,pdf;JA=pdf"
```

Format:

```text
DOCTYPE=ext1,ext2;DOCTYPE2=ext3
```

- `DOCTYPE` is the two-letter document type (characters 12–13 of the file name).
- Extensions are case-insensitive; the leading dot is optional (`pdf` and `.PDF`
  are the same).
- An empty list (`JC=`) allows nothing, so every copied file of that type is
  trashed.
- `*` allows every extension for that type (`JC=*`), which disables cleanup for
  it.
- Document types that are **not** listed are left completely untouched.
- Repeat the flag to add more rules; extensions for the same type are merged.

Only files copied into the destination are considered. Source files are never
moved, and unrelated files that already existed in the destination are ignored.

Cleanup runs as part of a copy. If the copy step is skipped (for example because
a previous copy exists and the prompt is declined), cleanup is skipped too; use
`--recopy` to apply new rules to an existing destination.

Disallowed files are moved into `<destination>/trash/`. The trash mirrors the
copy layout, so `D:\Sorted\DNSSGM12000JCSS700\file.dwg` becomes
`D:\Sorted\trash\DNSSGM12000JCSS700\file.dwg`. This keeps same-named files from
different code folders apart and shows where each file came from.

Behaviour on repeated runs:

- If the trash already holds an identical file (same size), the fresh copy in
  the destination is deleted and the existing trash path is recorded. No
  duplicates pile up in the trash.
- If the file changed, the trash copy is replaced with the new version.
- The `trash` folder is only created when at least one file has to move.
- The trash is one-way: changing `--allowed-types` later does not restore files
  that were already moved. Move them back manually if a rule was wrong.
- The final CSV write updates `Copied To` to the trash path for moved files.
- Trash warnings are reported but do not make the run fail.

Example result for `--allowed-types="JC=pdf;JA=dwg"`:

```text
D:\Sorted/
├─ DNSSGM12000JCSS700/
│  └─ DNSSGM12000JCSS70001-0001.pdf        <- kept (PDF is allowed for JC)
├─ no_code/
│  └─ T2404.pdf                           <- no document type rule, untouched
└─ trash/
   ├─ DNSSGH13900JACD00100-0001.dxf        <- JA only allows DWG
   └─ DNSSGM12000JCSS700/
      └─ DNSSGM12000JCSS70001-0001.dwg     <- DWG is not allowed for JC
```

### Flatten single-file folders (`--flatten-single-file-folders`)

After copying (and trash cleanup), a code folder can end up holding a single
file — for example when every other revision of the same code was moved to the
trash. Pass `--flatten-single-file-folders` to collapse those folders:

```bat
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --flatten-single-file-folders
```

Rules:

- Only the **direct children** of the destination are inspected; nested folders
  are left alone.
- A folder is flattened only when it contains **exactly one file**. Folders with
  several files, no files, or a single subfolder are left untouched, and empty
  folders that the step did not empty are kept.
- The file is moved into the destination root and the emptied folder is
  deleted.
- The `trash` folder and dot-prefixed folders are never touched, so trashed
  files stay trashed.
- If a file with the same name already exists in the root, the moved file gets
  ` (2)`, ` (3)`, ... before its extension, exactly like the copy step. Nothing
  is overwritten.
- The `Copied To` column is updated to the new root paths. Re-running the step
  is idempotent.

Example: `D:\Sorted\DNSSGM12000JCSS700\only-left.pdf` becomes
`D:\Sorted\only-left.pdf`, and the now-empty
`D:\Sorted\DNSSGM12000JCSS700` folder is removed.

### Rules file and the app editor

The associations can also be maintained in the **File Indexer** screen:

1. Index a folder.
2. Press **File Type Rules** in the results toolbar.
3. Each detected document type is shown with a chip per file extension found in
   the index. Checked extensions are kept; unchecked extensions are trashed by
   the CLI after copying.
4. **No rule** removes the assignment, keeping every file type for that
   document type.

Every change is written immediately to the shared rules file, so the CLI picks
it up on its next run. The file is a flat JSON map:

```json
{
  "JC": ["dwg", "pdf"],
  "JA": ["pdf"]
}
```

Document types missing from the file are left untouched during cleanup; an empty
list (`"JC": []`) trashes every copied file of that type.

The tool locates the file in this order:

1. `--allowed-types-file=<path>` when given.
2. The `FTFILESORTER_RULES_FILE` environment variable.
3. `%APPDATA%\FtFileSorter\allowed_types.json` (or a local `.ft_file_sorter`
   folder in the working directory when APPDATA is unavailable).

The File Indexer screen writes to the same location, and the dialog shows the
exact path. The CLI loads the shared file automatically whenever a copy is
requested and neither `--allowed-types` nor `--allowed-types-file` is given. An
explicit `--allowed-types` string overrides the file; the two flags cannot be
combined.

The shared file lives in the application-data folder rather than the repository
`config` folder so the GUI app and the CLI always resolve the *same* absolute
path: the app and the CLI are launched with different working directories, and
resolving through the working directory previously made the editor save one file
while the CLI read another. To keep the rules under version control in the
repository instead, point the tool at the repository file explicitly:

```bat
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted" --allowed-types-file "config/allowed_types.json"
```

### Preventing repeated work (prompts)

The tool remembers what it already did and asks before doing it again.

**Already indexed.** When the chosen CSV exists, the tool reads it and asks:

```text
An index already exists at "D:\exports\index.csv" (412 rows, saved 2026-10-27 14:05). Index the folder again? [y/N]
```

- Answering **no** reuses the existing CSV: no scan, no rewrite. The copy phase
  then works from the rows already in the CSV.
- Answering **yes** scans the folder again and writes a fresh CSV.
- `--reindex` always re-scans, `--reuse-index` always reuses, `--yes` answers
  yes.

**Already copied.** After a copy, the tool writes a small state file to
`<destination>/.ft_file_sorter_copy.json` containing the source root, mode, a
fingerprint of the indexed files, the copy time and the number of files. On the
next run against the same destination it asks:

```text
Destination "D:\Sorted" already contains a copy from 2026-10-27 14:12 (412 file(s)). Copy again? [y/N]
```

- Answering **no** skips the copy entirely.
- Answering **yes** runs the copy again; files of the same size are still
  skipped, so nothing is duplicated.
- `--recopy` skips the question and copies, `--yes` answers yes.
- If the source files changed since the recorded copy, the prompt says so.
- The state file is dot-prefixed, so the indexer ignores it if the destination
  ever sits inside a scanned folder.

**Non-interactive runs** (piped input, CI, scheduled tasks) cannot answer
prompts. They use the safe defaults: reuse an existing CSV and skip a repeated
copy. Pass `--reindex`, `--recopy`, or `--yes` to opt in explicitly.

### Document type

For reference, characters 12 and 13 of the file name form the two-letter
document type (for example `JC` in `DNSSGM12000JCSS70001-0001.dwg`). It is
written to the CSV, does not affect the copy layout, and drives the
`--allowed-types` cleanup.

### Examples

```bat
:: Index only, CSV next to the scanned folder
dart run tool/index_folder.dart "D:\Documents\AS BUILT"

:: Index only, explicit CSV path, root folder only
dart run tool/index_folder.dart "D:\Documents\AS BUILT" "D:\exports\index.csv" --no-recursive

:: Sort every file by document code, record destinations in the CSV
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv" --copy-by-code "D:\Sorted AS BUILT"

:: Sort, then trash extensions that are not wanted per document type
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv" --copy-by-code "D:\Sorted AS BUILT" --allowed-types "JC=dwg,pdf;JA=pdf"

:: Sort, clean up, then move single-file code folders into the destination root
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --flatten-single-file-folders

:: Same cleanup, but use the rules saved by the File Indexer screen
:: (%APPDATA%\FtFileSorter\allowed_types.json is loaded automatically)
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv" --copy-by-code "D:\Sorted AS BUILT"

:: Use a specific rules file
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --allowed-types-file "D:\exports\allowed_types.json"

:: Multiple rules with explicit dots and wildcards
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-by-code "D:\Sorted AS BUILT" --allowed-types="JC=dwg,.PDF;JA=*;CA="

:: First run in a scheduled task: index and copy without prompts
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv" --copy-by-code "D:\Sorted AS BUILT" --allowed-types="JC=dwg,pdf;JA=pdf" --yes

:: Force a fresh index and a fresh copy, replacing existing files
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --csv "D:\exports\index.csv" --copy-by-code "D:\Sorted AS BUILT" --reindex --recopy --overwrite-duplicates

:: Copy duplicate document codes only (legacy mode)
dart run tool/index_folder.dart "D:\Documents\AS BUILT" --copy-duplicates "D:\Duplicate Codes"
```

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Index and any requested copy finished, or a prompt was declined. |
| `1` | Indexing failed, or every requested copy failed. |
| `64` | Invalid arguments (usage error). |

### Notes

- The **File Indexer** screen uses the same indexing service and offers the
  duplicate-only copy mode through its "Copy duplicate document codes" switch.
  After copying it moves disallowed file types into `<destination>/trash/` using
  the shared rules edited in the File Type Rules dialog, and its CSV export
  includes the `Copied To` column reflecting those final paths. The
  **Flatten single-file folders** switch (on by default) applies the flatten
  step described above after the copy and cleanup. The sort-everything copy mode
  is CLI-only.
- Debug logging is printed to the console for every indexed and copied file.
