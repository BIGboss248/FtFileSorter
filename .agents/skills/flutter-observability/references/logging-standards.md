# Logging Standards & Desktop Persistence (`flutter-observability`)

## Structured Logging Pattern

Use the `logger` package with clear level semantics:

```dart
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  static void info(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
```

## Desktop File Logging

On desktop platforms (Windows, macOS, Linux), persistent file logging assists in debugging user-reported crashes:
- Store log files under `getApplicationSupportDirectory()`.
- Implement size limits (e.g. 5 MB) and rotate past logs (`app.1.log`, `app.2.log`).
- Scrub sensitive authorization headers (`Bearer ***`) before writing to disk.
