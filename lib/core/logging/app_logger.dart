import 'dart:io';

import 'package:logger/logger.dart';

/// Whether the app was compiled ahead-of-time for release.
const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

/// `flutter test` sets this variable. Tests keep only warnings and errors so
/// the suite output stays readable.
final bool _isRunningTests = Platform.environment.containsKey('FLUTTER_TEST');

/// Minimum level that is emitted.
///
/// * development: everything, including per-file trace output
/// * release: info and above, so diagnostics stay available in the field
/// * tests: warnings and errors only
Level get appLogLevel {
  if (_isRunningTests) return Level.warning;
  if (_isReleaseBuild) return Level.info;
  return Level.trace;
}

/// Creates a logger tagged with [name], e.g. `[FileIndexService]`.
///
/// Messages are written to the console with a level label (`TRACE`, `DEBUG`,
/// `INFO`, `WARN`, `ERROR`) and an optional error plus a short stack trace.
Logger createLogger(String name) {
  // ProductionFilter only checks the level. DevelopmentFilter additionally
  // relies on asserts being enabled, which is false under `dart run`, so it
  // would silently drop every message outside `flutter run`/`flutter test`.
  return Logger(
    filter: ProductionFilter(),
    level: appLogLevel,
    printer: _NamedPrinter(name),
  );
}

/// Compact, dependency-free output so logs stay readable next to `flutter run`
/// output and in the `dart run` CLI.
class _NamedPrinter extends LogPrinter {
  _NamedPrinter(this.name);

  final String name;

  @override
  List<String> log(LogEvent event) {
    final buffer = StringBuffer()
      ..write('[$name] ')
      ..write(_label(event.level))
      ..write(event.message);

    if (event.error != null) {
      buffer.write(' | error: ${event.error}');
    }

    final lines = <String>[buffer.toString()];

    final stackTrace = event.stackTrace;
    if (stackTrace != null) {
      for (final line in stackTrace.toString().trim().split('\n').take(6)) {
        lines.add('[$name]        $line');
      }
    }

    return lines;
  }

  static String _label(Level level) {
    return switch (level) {
      Level.trace => 'TRACE   ',
      Level.debug => 'DEBUG   ',
      Level.info => 'INFO    ',
      Level.warning => 'WARN    ',
      Level.error => 'ERROR   ',
      Level.fatal => 'FATAL   ',
      _ => 'LOG     ',
    };
  }
}
