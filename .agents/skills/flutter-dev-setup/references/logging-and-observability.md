# Structured Logging & Observability (`flutter-dev-setup`)

A dependency-light, console-first logging system that works identically in
`flutter run`, `flutter test`, release builds, and plain `dart run` scripts.
Deploy it once per project, then instrument every service and long-lived widget
with a named logger.

---

## 1. Why `logger` instead of `print` or `logging`

| Option | Verdict |
| --- | --- |
| `print` | Banned by `avoid_print`; no levels, no filtering, no stack traces. |
| `package:logging` | Fine for pure Dart, but no built-in console formatting or level-aware output. |
| `package:logger` | Small, pure Dart, level-aware (`trace` → `fatal`), works in isolates and CLIs, pluggable printer/output. |

Use `package:logger` unless the project has already standardized on something
else. It has no Flutter dependency, so services remain usable from `dart run`
tools and unit tests.

```powershell
flutter pub add logger
```

---

## 2. Level policy

The logger derives its minimum level from the build mode. No configuration or
platform channel is required.

| Environment | Minimum level | Rationale |
| --- | --- | --- |
| Debug / profile (`flutter run`) | `Level.trace` | Full detail while developing. |
| Release (`flutter build --release`) | `Level.info` | Keep lifecycle and failure diagnostics without trace noise. |
| Tests (`flutter test`) | `Level.warning` | Only problems pollute CI output. |

Override per-logger or per-call via `createLogger(name, level: ...)`.

### Level semantics

| Level | Use it for | Examples |
| --- | --- | --- |
| `TRACE` | Per-item detail, hot paths | Each file parsed, each CSV row, each directory entered, each keystroke. |
| `DEBUG` | Developer-facing flow and state | Picker opened, page changed, isolate spawned, filter applied. |
| `INFO` | Completed operations and summaries | "Indexed 139 files in 38 folders in 412 ms", "CSV written (814 bytes)". |
| `WARN` | Recoverable problems | Empty scan, unreadable file skipped, scan finished with warnings. |
| `ERROR` | Operation failed | Missing folder, scan failure, export failure — always with `error:` and `stackTrace:`. |

Rules of thumb:

- Log operation **boundaries**, not every statement: entry, exit, timing, failure.
- Put counts, paths, durations, and identifiers in `INFO`/`DEBUG` messages.
- Use `TRACE` for loops; never put per-item logging above `TRACE`.
- Never log secrets, tokens, credentials, or document contents. File paths can
  contain usernames; keep sensitive-path logging at `TRACE`/`DEBUG` and consider
  logging only the file name in production.
- Never call the logger from `build()` or other high-frequency render paths.

---

## 3. Wiring

1. Copy [app_logger.dart.template](../resources/templates/app_logger.dart.template)
   to `lib/core/logging/app_logger.dart`.
2. Import it with a relative path from services/widgets, or use the package
   import if `lib/` is exported.
3. Create one lazily initialized logger per class:

```dart
import '../../../core/logging/app_logger.dart';

class FileIndexService {
  static final _log = createLogger('FileIndexService');

  Future<void> index() async {
    _log.d('index() requested');
    final stopwatch = Stopwatch()..start();

    try {
      // ... work ...
      stopwatch.stop();
      _log.i('Indexed 139 files in 412 ms.');
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log.e(
        'Indexing failed after ${stopwatch.elapsedMilliseconds} ms.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

Why `static final` instead of a top-level global? It is initialized on first
use, avoids import cycles, keeps the tag close to the code, and is safe inside
background isolates.

### Output format

```
[FileIndexService] INFO    Indexed 139 file(s) in 38 folder(s) in 412 ms: D:\Archive
[FileIndexerScreen] DEBUG   Folder selected: "D:\Archive".
[FileIndexService] WARN    Could not read file metadata: D:\Archive\locked.pdf | error: ...
```

---

## 4. Instrumentation recipes

### Service

Log entry with options, exit with a summary and duration, and failures at
`ERROR` with both `error` and `stackTrace`. Add `WARN` when a recoverable
problem is collected for the caller (e.g. skipped entries).

```dart
static final _log = createLogger('OrderRepository');

Future<Order> submit(Order order) async {
  _log.d('submit(orderId: ${order.id}, lines: ${order.lines.length})');
  final stopwatch = Stopwatch()..start();

  try {
    final saved = await _api.post(order);
    stopwatch.stop();
    _log.i('Order ${saved.id} submitted in ${stopwatch.elapsedMilliseconds} ms.');
    return saved;
  } catch (error, stackTrace) {
    stopwatch.stop();
    _log.e('Order ${order.id} submission failed.', error: error, stackTrace: stackTrace);
    rethrow;
  }
}
```

### Widget / screen

Log user intent and state transitions — never the render method.

```dart
class DocumentScreenState extends State<DocumentScreen> {
  static final _log = createLogger('DocumentScreen');

  Future<void> _pickFile() async {
    _log.d('File picker opened.');
    final path = await FilePicker.platform.pickFiles();
    if (path == null) {
      _log.d('File picker cancelled.');
      return;
    }
    _log.i('File selected: "${path.files.single.name}".');
  }

  @override
  void dispose() {
    _log.t('DocumentScreen disposed.');
    super.dispose();
  }
}
```

Also log: page/tab changes, filter changes, toggles, ignored/duplicate requests,
and export/import results with durations.

### Background isolate

Create the logger **inside** the isolate; never send a `Logger` across an
isolate boundary.

```dart
Future<Summary> runInBackground(String path) {
  return Isolate.run(() => _scan(path));
}

Summary _scan(String path) {
  final log = createLogger('ScanWorker'); // created inside the isolate
  log.d('Scan started: $path');
  // ...
  log.i('Scan finished: $count files.');
}
```

Because `ProductionFilter` only checks levels, logs from isolates still reach
the console.

### CLI / `dart run`

The same logger works in plain Dart scripts. Add one named logger per command:

```dart
final log = createLogger('cli');
log.d('Arguments: $arguments');
log.i('Wrote 139 rows to $outputPath');
```

---

## 5. Critical pitfalls

### `DevelopmentFilter` silently drops logs under `dart run`

`logger`'s `DevelopmentFilter` wraps its check in an `assert`. Asserts are
enabled by `flutter run`/`flutter test` but **disabled** by default under
`dart run`, so every message disappears from CLI tools. Always use
`ProductionFilter` and control verbosity through `appLogLevel` (or an explicit
`level` argument). This is the single most common reason "logging works in the
app but not in the tool".

### Isolate sendability

Do not capture a `Logger`, `Directory`, `RandomAccessFile`, or other native
objects in an `Isolate.run` closure. Create the logger in the closure and pass
only plain values (`String`, `bool`, `List<String>`).

### Web builds

`app_logger.dart` imports `dart:io` for `Platform.environment`. For web targets:

```dart
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

Level get appLogLevel => kDebugMode ? Level.trace : Level.info;
```

Drop the `FLUTTER_TEST` detection (no filesystem environment on web). If tests
are run with `flutter test --platform chrome`, expose an explicit setter or pass
`level:` in test setup instead.

### Test noise

`appLogLevel` already lowers tests to `warning`. If a service test deliberately
triggers an `ERROR`, that line is expected; do not suppress it globally.

### Eager message evaluation

`logger` evaluates the message expression before filtering. Avoid expensive
work (full directory scans, JSON serialization) purely to build a `TRACE`
message in a hot loop. Guard with a cheap condition or keep the message to
counts and identifiers.

---

## 6. Verifying and testing

Use `MemoryOutput` to assert that a service logs at the expected level without
polluting the console:

```dart
test('logs an error when the folder is missing', () async {
  final output = MemoryOutput();
  final log = createLogger('FileIndexService', level: Level.trace, output: output);

  log.e('Folder does not exist: /missing');

  expect(output.buffer.single.level, Level.error);
  expect(output.buffer.single.lines.join('\n'), contains('Folder does not exist'));
});
```

Verification checklist:

- [ ] `flutter run` shows `TRACE`/`DEBUG`/`INFO` lines with `[Tag] LEVEL` prefixes.
- [ ] `dart run tool/<cli>.dart` shows the same formatting (proves `ProductionFilter` is used).
- [ ] `flutter test` output contains only `WARN`/`ERROR` lines (plus intentional test errors).
- [ ] `flutter build <target> --release` still compiles and logs `INFO` and above.
- [ ] No `print(...)` calls remain (`flutter analyze --fatal-infos`).

---

## 7. Optional: richer observability

This logging layer covers console diagnostics and operation tracing. For
production crash reporting, network interceptors, BLoC/state tracing, or remote
log shipping, pair it with the **`flutter-observability`** skill. Keep the
`createLogger` API as the local logging facade so swapping or fanning out the
`LogOutput` later does not require touching every call site.

---

## 8. Tuning

- Change the global minimum: edit `appLogLevel` in `app_logger.dart`.
- Dev-only override: `flutter run --dart-define=...` requires reading the define
  in `appLogLevel` (optional; not enabled by default).
- Per-module verbosity: `createLogger('NoisyService', level: Level.info)`.
- File/remote output: pass `output: MultiOutput([ConsoleOutput(), FileOutput(...)])`
  or a custom `LogOutput`; call sites stay unchanged.
