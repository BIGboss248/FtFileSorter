import 'dart:convert';
import 'dart:io';

import 'package:ft_file_sorter/core/logging/app_logger.dart';
import 'package:ft_file_sorter/src/data/models/indexed_file.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:path/path.dart' as p;

/// File written inside a copy destination to remember the last copy run.
///
/// Dot-prefixed so the indexer ignores it when the destination happens to sit
/// inside the scanned tree.
const String _copyStateFileName = '.ft_file_sorter_copy.json';

const String _usage =
    'Usage: dart run tool/index_folder.dart <folder> [output.csv] [options]\n'
    '\n'
    'Options:\n'
    '  --csv=<path>               Save the CSV to <path> (overrides [output.csv]).\n'
    '  --no-recursive             Only index the direct children of <folder>.\n'
    '  --copy-by-code=<dest>      Copy every file: shared codes get a folder,\n'
    '                             unique codes go directly into <dest>, names\n'
    '                             without a complete code go to <dest>/no_code/.\n'
    '  --copy-duplicates=<dest>   Copy only files whose code is shared.\n'
    '  --overwrite-duplicates     Replace files already present in <dest>.\n'
    '  --reindex                  Index again even when a CSV already exists.\n'
    '  --reuse-index              Reuse an existing CSV without asking.\n'
    '  --recopy                   Copy again even when <dest> already has a copy.\n'
    '  --yes, -y                  Answer yes to the index and copy prompts.\n'
    '  --help, -h                 Show this help.\n'
    '\n'
    'The copy destination recorded for every file is written to the CSV\n'
    '"Copied To" column. A failed or skipped copy leaves it unchanged.';

enum _CopyMode { byCode, duplicates }

/// Indexes a folder, writes a CSV, and optionally copies files by document code.
///
/// The tool runs in two phases:
///
/// 1. **Index** — scans `<folder>` and writes the CSV (default
///    `<folder>/file_index.csv`). When a reusable CSV already exists the user is
///    asked whether to index again; pass `--reuse-index` to reuse it silently,
///    `--reindex` to always scan, or `--yes` to answer yes to the prompt.
/// 2. **Copy** — when `--copy-by-code` or `--copy-duplicates` is given, the
///    files are copied into the destination and the final CSV is rewritten with
///    the `Copied To` path for every file. If that destination already holds a
///    copy from a previous run, the user is asked before copying again; pass
///    `--recopy` to bypass the prompt or `--yes` to answer yes.
///
/// See `tool/README.md` for the full flag reference and the destination layout.
Future<void> main(List<String> arguments) async {
  final log = createLogger('index_folder');
  log.d('CLI arguments: $arguments');

  final options = _Options.parse(arguments);
  if (options == null) return;

  const service = FileIndexService();
  final csvFile = File(options.csvPath);
  final csvExists = await csvFile.exists();

  // ---------------------------------------------------------------- Index
  CsvIndexData? existing;
  if (csvExists) {
    try {
      existing = await service.readCsv(options.csvPath);
    } on FormatException catch (error) {
      log.w('Existing CSV cannot be reused: ${error.message}');
      stderr.writeln(
        'Warning: existing CSV cannot be reused (${error.message}). '
        'Indexing again.',
      );
    } on FileSystemException catch (error) {
      log.w('Existing CSV could not be read: ${error.message}');
    }
  }

  var reindex = true;
  if (existing != null) {
    if (options.reuseIndex) {
      reindex = false;
      stdout.writeln('Reusing the existing index (--reuse-index).');
    } else if (!options.reindex) {
      final modified = await csvFile.lastModified();
      reindex = await _confirm(
        'An index already exists at "${options.csvPath}" '
        '(${existing.totalFiles} rows, saved ${_formatTimestamp(modified)}). '
        'Index the folder again?',
        fallback: false,
        assumeYes: options.assumeYes,
      );
    }
  } else if (options.reuseIndex) {
    log.w('--reuse-index was given but no reusable CSV exists.');
    stderr.writeln(
      'Warning: --reuse-index was given but no reusable CSV exists. '
      'Indexing instead.',
    );
  }

  var files = const <IndexedFile>[];
  final copiedTo = <String, String>{};

  if (existing != null && !reindex) {
    files = existing.files;
    copiedTo.addAll(existing.copiedTo);
    log.i(
      'Reused existing index: ${files.length} file(s) from "${options.csvPath}".',
    );

    stdout
      ..writeln(
        'Reused index: ${files.length} file(s) from "${options.csvPath}".',
      )
      ..writeln('Document types: ${_documentTypes(files).join(', ')}')
      ..writeln('File types: ${_extensions(files).join(', ')}');
  } else {
    log.i(
      'Indexing "${options.folder}" (recursive=${options.recursive}) -> '
      'CSV "${options.csvPath}".',
    );

    try {
      final result = await service.indexDirectory(
        options.folder,
        recursive: options.recursive,
        excludePaths: {options.csvPath},
      );

      files = result.files;
      if (existing != null) copiedTo.addAll(existing.copiedTo);

      // Write the index immediately so the CSV exists even if copying fails.
      await service.writeCsv(options.csvPath, files, copiedTo: copiedTo);
      log.i(
        'Index written: ${result.totalFiles} row(s) -> ${options.csvPath}.',
      );

      stdout
        ..writeln(
          'Indexed ${result.totalFiles} files '
          'in ${result.scannedDirectories} folders.',
        )
        ..writeln('Document types: ${result.documentTypes.join(', ')}')
        ..writeln('File types: ${result.extensions.join(', ')}')
        ..writeln('CSV written to: ${options.csvPath}');

      for (final warning in result.warnings) {
        log.w(warning);
      }
    } on FileSystemException catch (error, stackTrace) {
      log.e(
        'Failed to index "${options.folder}".',
        error: error,
        stackTrace: stackTrace,
      );
      stderr.writeln('Failed to index "${options.folder}": ${error.message}');
      exitCode = 1;
      return;
    }
  }

  // ----------------------------------------------------------------- Copy
  final copyDestination = options.copyDestination;
  if (copyDestination == null) return;

  try {
    final destination = p.normalize(p.absolute(copyDestination));
    final statePath = p.join(destination, _copyStateFileName);
    final previous = await _CopyState.read(statePath);
    final fingerprint = _fingerprint(files);

    var shouldCopy = true;
    if (previous != null && !options.recopy) {
      final sourceChanged = previous.sourceFingerprint != fingerprint;
      shouldCopy = await _confirm(
        'Destination "$destination" already contains a copy from '
        '${_formatTimestamp(previous.copiedAt)} '
        '(${previous.copiedCount} file(s)${sourceChanged ? ', and the source has changed since then' : ''}). '
        'Copy again?',
        fallback: false,
        assumeYes: options.assumeYes,
      );
    }

    if (!shouldCopy) {
      log.i('Copy skipped: destination already has a copy.');
      stdout.writeln(
        'Copy skipped. Pass --recopy (or answer yes) to copy again.',
      );
      if (copiedTo.isEmpty) {
        stdout.writeln(
          'Note: the rebuilt CSV has no copy destinations because the copy '
          'was skipped. Run with --recopy to record them.',
        );
      }
      return;
    }

    final copyResult = options.copyMode == _CopyMode.byCode
        ? await service.copyFilesByCode(
            files,
            destinationRoot: destination,
            overwrite: options.overwrite,
          )
        : await service.copyDuplicateCodeGroups(
            files,
            destinationRoot: destination,
            overwrite: options.overwrite,
          );

    // The CSV should describe this copy run, so replace any destinations
    // carried over from an earlier CSV instead of mixing destinations.
    copiedTo
      ..clear()
      ..addAll(copyResult.copiedToBySource);

    // Rewrite the same CSV now that every copy destination is known.
    await service.writeCsv(options.csvPath, files, copiedTo: copiedTo);

    if (copyResult.copiedToBySource.isNotEmpty) {
      await _CopyState(
        mode: options.copyMode!.name,
        sourceRoot: p.normalize(p.absolute(options.folder)),
        destinationRoot: destination,
        sourceFingerprint: fingerprint,
        copiedAt: DateTime.now(),
        copiedCount: copyResult.copiedToBySource.length,
        groupCount: copyResult.totalGroups,
        looseCount: copyResult.totalLoose,
        noCodeCount: copyResult.totalNoCode,
      ).write(statePath);
    }
    log.i(
      'Copy finished: ${copyResult.totalCopied} copied, '
      '${copyResult.totalSkipped} skipped, ${copyResult.warnings.length} '
      'warning(s); CSV updated with ${copyResult.copiedToBySource.length} '
      'destination(s).',
    );

    _printCopySummary(copyResult, options.copyMode!);
    stdout.writeln('CSV updated with copy destinations: ${options.csvPath}');

    for (final warning in copyResult.warnings) {
      log.w(warning);
      stderr.writeln('Warning: $warning');
    }

    if (copyResult.hasWarnings && copyResult.totalCopied == 0) {
      exitCode = 1;
    }
  } on FileSystemException catch (error, stackTrace) {
    log.e(
      'Copy failed for destination "$copyDestination".',
      error: error,
      stackTrace: stackTrace,
    );
    stderr.writeln(
      'Copy failed for destination "$copyDestination": ${error.message}',
    );
    exitCode = 1;
  }
}

/// Parsed command-line options, or `null` after a usage error.
class _Options {
  final String folder;
  final String csvPath;
  final bool recursive;
  final _CopyMode? copyMode;
  final String? copyDestination;
  final bool overwrite;
  final bool reindex;
  final bool reuseIndex;
  final bool recopy;
  final bool assumeYes;

  const _Options({
    required this.folder,
    required this.csvPath,
    required this.recursive,
    required this.copyMode,
    required this.copyDestination,
    required this.overwrite,
    required this.reindex,
    required this.reuseIndex,
    required this.recopy,
    required this.assumeYes,
  });

  static _Options? parse(List<String> arguments) {
    final positional = <String>[];
    final unknown = <String>[];
    String? csvPath;
    String? byCodeDestination;
    String? duplicateDestination;
    var recursive = true;
    var overwrite = false;
    var reindex = false;
    var reuseIndex = false;
    var recopy = false;
    var assumeYes = false;

    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i].trim();

      if (argument == '--help' || argument == '-h') {
        stdout.writeln(_usage);
        exitCode = 0;
        return null;
      }
      if (argument == '--no-recursive') {
        recursive = false;
        continue;
      }
      if (argument == '--recursive') {
        recursive = true;
        continue;
      }
      if (argument == '--overwrite-duplicates') {
        overwrite = true;
        continue;
      }
      if (argument == '--reindex') {
        reindex = true;
        continue;
      }
      if (argument == '--reuse-index') {
        reuseIndex = true;
        continue;
      }
      if (argument == '--recopy') {
        recopy = true;
        continue;
      }
      if (argument == '--yes' || argument == '-y') {
        assumeYes = true;
        continue;
      }

      const valueFlags = {
        '--csv': 'csv',
        '--copy-by-code': 'byCode',
        '--copy-duplicates': 'duplicates',
      };
      if (valueFlags.containsKey(argument)) {
        if (i + 1 >= arguments.length) {
          _usageError('Missing value after $argument.');
          return null;
        }
        final value = arguments[++i].trim();
        switch (valueFlags[argument]) {
          case 'csv':
            csvPath = value;
          case 'byCode':
            byCodeDestination = value;
          case 'duplicates':
            duplicateDestination = value;
        }
        continue;
      }

      if (argument.startsWith('--csv=')) {
        csvPath = argument.substring('--csv='.length).trim();
        continue;
      }
      if (argument.startsWith('--copy-by-code=')) {
        byCodeDestination = argument.substring('--copy-by-code='.length).trim();
        continue;
      }
      if (argument.startsWith('--copy-duplicates=')) {
        duplicateDestination = argument
            .substring('--copy-duplicates='.length)
            .trim();
        continue;
      }
      if (argument.startsWith('--')) {
        unknown.add(argument);
        continue;
      }

      positional.add(argument);
    }

    for (final flag in unknown) {
      stderr.writeln('Warning: ignoring unknown flag "$flag".');
    }

    if (positional.isEmpty || positional.first.isEmpty) {
      _usageError('Missing required <folder> argument.');
      return null;
    }
    if (reindex && reuseIndex) {
      _usageError('--reindex and --reuse-index cannot be combined.');
      return null;
    }
    if (byCodeDestination != null && duplicateDestination != null) {
      _usageError('--copy-by-code and --copy-duplicates cannot be combined.');
      return null;
    }

    final copyDestination = byCodeDestination ?? duplicateDestination;
    final copyMode = byCodeDestination != null
        ? _CopyMode.byCode
        : duplicateDestination != null
        ? _CopyMode.duplicates
        : null;

    if (copyDestination != null && copyDestination.isEmpty) {
      _usageError('The copy destination must not be empty.');
      return null;
    }
    if (csvPath != null && csvPath.isEmpty) {
      _usageError('The --csv path must not be empty.');
      return null;
    }

    final folder = positional.first;
    if (csvPath != null && positional.length > 1) {
      stderr.writeln(
        'Warning: ignoring "${positional[1]}" because --csv was given.',
      );
    }

    final resolvedCsvPath =
        csvPath ??
        (positional.length > 1
            ? positional[1]
            : p.join(p.normalize(folder), 'file_index.csv'));

    return _Options(
      folder: folder,
      csvPath: resolvedCsvPath,
      recursive: recursive,
      copyMode: copyMode,
      copyDestination: copyDestination,
      overwrite: overwrite,
      reindex: reindex,
      reuseIndex: reuseIndex,
      recopy: recopy,
      assumeYes: assumeYes,
    );
  }

  static void _usageError(String message) {
    stderr
      ..writeln(message)
      ..writeln(_usage);
    exitCode = 64;
  }
}

/// Persisted copy metadata used to detect an earlier copy into a destination.
class _CopyState {
  static const int _version = 1;

  final String mode;
  final String sourceRoot;
  final String destinationRoot;
  final String sourceFingerprint;
  final DateTime copiedAt;
  final int copiedCount;
  final int groupCount;
  final int looseCount;
  final int noCodeCount;

  const _CopyState({
    required this.mode,
    required this.sourceRoot,
    required this.destinationRoot,
    required this.sourceFingerprint,
    required this.copiedAt,
    required this.copiedCount,
    required this.groupCount,
    required this.looseCount,
    required this.noCodeCount,
  });

  Map<String, Object?> toJson() => {
    'version': _version,
    'mode': mode,
    'sourceRoot': sourceRoot,
    'destinationRoot': destinationRoot,
    'sourceFingerprint': sourceFingerprint,
    'copiedAt': copiedAt.toIso8601String(),
    'copiedCount': copiedCount,
    'groupCount': groupCount,
    'looseCount': looseCount,
    'noCodeCount': noCodeCount,
  };

  static Future<_CopyState?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final copiedAt = DateTime.tryParse(decoded['copiedAt']?.toString() ?? '');
      if (copiedAt == null) return null;

      int readInt(String key) {
        final value = decoded[key];
        return value is num ? value.toInt() : 0;
      }

      return _CopyState(
        mode: decoded['mode']?.toString() ?? '',
        sourceRoot: decoded['sourceRoot']?.toString() ?? '',
        destinationRoot: decoded['destinationRoot']?.toString() ?? '',
        sourceFingerprint: decoded['sourceFingerprint']?.toString() ?? '',
        copiedAt: copiedAt,
        copiedCount: readInt('copiedCount'),
        groupCount: readInt('groupCount'),
        looseCount: readInt('looseCount'),
        noCodeCount: readInt('noCodeCount'),
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
      encoding: utf8,
      flush: true,
    );
  }
}

/// Asks a yes/no question. Non-interactive runs use [fallback].
Future<bool> _confirm(
  String question, {
  required bool fallback,
  required bool assumeYes,
}) async {
  if (assumeYes) {
    stdout.writeln('$question yes (--yes)');
    return true;
  }

  final hint = fallback ? '[Y/n]' : '[y/N]';

  if (!stdin.hasTerminal) {
    stdout.writeln(
      '$question $hint ${fallback ? 'yes' : 'no'} (non-interactive default)',
    );
    return fallback;
  }

  stdout.write('$question $hint ');

  try {
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer == null) {
      stdout.writeln();
      return fallback;
    }
    if (answer.isEmpty) return fallback;
    return answer == 'y' || answer == 'yes';
  } on StdinException {
    stdout.writeln(
      'no console input available, using ${fallback ? 'yes' : 'no'}',
    );
    return fallback;
  }
}

/// Compact, stable fingerprint of an index used to detect source changes.
String _fingerprint(List<IndexedFile> files) {
  var hash = 0x811c9dc5;
  const prime = 0x01000193;
  const mask = 0xFFFFFFFF;

  void add(String value) {
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * prime) & mask;
    }
  }

  for (final file in files) {
    add(file.fullPath.toLowerCase());
    add('|${file.sizeInBytes}');
    add('|${file.lastModified?.millisecondsSinceEpoch ?? 0}\n');
  }

  return hash.toRadixString(16).padLeft(8, '0');
}

List<String> _documentTypes(List<IndexedFile> files) {
  final types =
      files
          .map((file) => file.documentTypeCode)
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return types;
}

List<String> _extensions(List<IndexedFile> files) {
  final extensions =
      files
          .map((file) => file.extension)
          .where((extension) => extension.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return extensions;
}

String _formatTimestamp(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

void _printCopySummary(DuplicateCopyResult result, _CopyMode mode) {
  stdout.writeln('Destination: ${result.destinationRoot}');

  if (mode == _CopyMode.byCode) {
    stdout.writeln(
      'Copied ${result.totalCopied} file(s): '
      '${result.totalGroups} code folder(s), '
      '${result.totalLoose} unique file(s) directly in the destination, '
      '${result.totalNoCode} no-code file(s) in '
      '${DuplicateCopyResult.noCodeFolderName}/.',
    );
  } else {
    stdout.writeln(
      'Copied ${result.totalCopied} file(s) into '
      '${result.totalGroups} code folder(s).',
    );
  }

  for (final group in result.groups) {
    stdout.writeln('  ${group.code}: ${group.fileCount} file(s)');
  }

  if (result.totalSkipped > 0) {
    stdout.writeln(
      'Skipped ${result.totalSkipped} file(s) that were already up to date.',
    );
  }
}
