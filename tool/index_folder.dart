import 'dart:io';

import 'package:ft_file_sorter/core/logging/app_logger.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:path/path.dart' as p;

/// Indexes a folder and writes the CSV used by the File Indexer screen.
///
/// Usage:
///   `dart run tool/index_folder.dart <folder> [output.csv] [--no-recursive]`
///   `[--copy-by-code=<destination>] [--copy-duplicates=<destination>]`
///   `[--overwrite-duplicates]`
///
/// When [output.csv] is omitted the file is written next to the scanned folder
/// as `file_index.csv`.
///
/// `--copy-by-code=<destination>` copies every indexed file into the
/// destination, sorted by document code:
///
/// * a complete 18-character code shared by two or more files gets its own
///   folder: `<destination>/<document code>/`;
/// * a complete code that belongs to a single file is copied directly into
///   `<destination>/` without a folder of its own;
/// * files whose names are shorter than a complete code go into
///   `<destination>/no_code/`.
///
/// `--copy-duplicates=<destination>` is the older, narrower mode: it only
/// copies files whose complete code is shared by at least one other file into
/// `<destination>/<document code>/`.
///
/// Both copy flags can be written without `=`, in which case the next argument
/// is used as the destination: `--copy-by-code "D:\Sorted"`. They cannot be
/// combined with each other.
///
/// `--overwrite-duplicates` replaces files that already exist in the
/// destination instead of keeping them. It applies to either copy mode.
Future<void> main(List<String> arguments) async {
  final log = createLogger('index_folder');
  log.d('CLI arguments: $arguments');

  const byCodePrefix = '--copy-by-code=';
  const duplicatesPrefix = '--copy-duplicates=';
  const usage =
      'Usage: dart run tool/index_folder.dart <folder> [output.csv] '
      '[--no-recursive] [--copy-by-code=<destination>] '
      '[--copy-duplicates=<destination>] [--overwrite-duplicates]';

  final positional = <String>[];
  final unknownFlags = <String>[];
  String? byCodeDestination;
  String? duplicateDestination;
  var recursive = true;
  var overwriteDuplicates = false;

  void missingValue(String flag) {
    log.e('Missing destination after $flag.');
    stderr.writeln('Missing destination after $flag.');
    stderr.writeln(usage);
    exitCode = 64;
  }

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i].trim();

    if (argument == '--no-recursive') {
      recursive = false;
      continue;
    }
    if (argument == '--recursive') {
      recursive = true;
      continue;
    }
    if (argument == '--overwrite-duplicates') {
      overwriteDuplicates = true;
      continue;
    }
    if (argument == '--copy-by-code' || argument == '--copy-duplicates') {
      if (i + 1 >= arguments.length) {
        missingValue(argument);
        return;
      }
      final value = arguments[++i].trim();
      if (argument == '--copy-by-code') {
        byCodeDestination = value;
      } else {
        duplicateDestination = value;
      }
      continue;
    }
    if (argument.startsWith(byCodePrefix)) {
      byCodeDestination = argument.substring(byCodePrefix.length).trim();
      continue;
    }
    if (argument.startsWith(duplicatesPrefix)) {
      duplicateDestination = argument.substring(duplicatesPrefix.length).trim();
      continue;
    }
    if (argument.startsWith('--')) {
      unknownFlags.add(argument);
      continue;
    }
    positional.add(argument);
  }

  for (final flag in unknownFlags) {
    log.w('Ignoring unknown flag: $flag');
    stderr.writeln('Warning: ignoring unknown flag "$flag".');
  }

  if (positional.isEmpty) {
    log.e('Missing required <folder> argument.');
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }

  if (byCodeDestination != null && duplicateDestination != null) {
    log.e('--copy-by-code and --copy-duplicates cannot be combined.');
    stderr.writeln('--copy-by-code and --copy-duplicates cannot be combined.');
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }

  final copyDestination = byCodeDestination ?? duplicateDestination;
  if (copyDestination != null && copyDestination.isEmpty) {
    log.e('The copy destination is empty.');
    stderr.writeln('The copy destination must not be empty.');
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }

  final folder = positional.first;
  final outputPath = positional.length > 1
      ? positional[1]
      : p.join(p.normalize(folder), 'file_index.csv');

  log.i('Indexing "$folder" (recursive=$recursive) -> CSV "$outputPath".');

  const service = FileIndexService();

  try {
    final result = await service.indexDirectory(
      folder,
      recursive: recursive,
      excludePaths: {outputPath},
    );

    final writtenPath = await service.writeCsv(outputPath, result.files);
    log.i('CLI finished: ${result.totalFiles} row(s) written to $writtenPath.');

    stdout
      ..writeln(
        'Indexed ${result.totalFiles} files '
        'in ${result.scannedDirectories} folders.',
      )
      ..writeln('Document types: ${result.documentTypes.join(', ')}')
      ..writeln('File types: ${result.extensions.join(', ')}')
      ..writeln('CSV written to: $writtenPath');

    for (final warning in result.warnings) {
      log.w(warning);
    }

    if (copyDestination == null) return;

    final copyResult = byCodeDestination != null
        ? await service.copyFilesByCode(
            result.files,
            destinationRoot: copyDestination,
            overwrite: overwriteDuplicates,
          )
        : await service.copyDuplicateCodeGroups(
            result.files,
            destinationRoot: copyDestination,
            overwrite: overwriteDuplicates,
          );

    stdout.writeln('Destination: ${copyResult.destinationRoot}');

    if (byCodeDestination != null) {
      stdout.writeln(
        'Copied ${copyResult.totalCopied} file(s): '
        '${copyResult.totalGroups} code folder(s), '
        '${copyResult.totalLoose} unique file(s) directly in the destination, '
        '${copyResult.totalNoCode} no-code file(s) in '
        '${DuplicateCopyResult.noCodeFolderName}/.',
      );

      for (final group in copyResult.groups) {
        stdout.writeln('  ${group.code}: ${group.fileCount} file(s)');
      }
    } else {
      stdout.writeln(
        'Copied ${copyResult.totalCopied} file(s) into '
        '${copyResult.totalGroups} code folder(s).',
      );

      for (final group in copyResult.groups) {
        stdout.writeln('  ${group.code}: ${group.fileCount} file(s)');
      }
    }

    if (copyResult.totalSkipped > 0) {
      stdout.writeln(
        'Skipped ${copyResult.totalSkipped} file(s) that were already '
        'up to date.',
      );
    }

    for (final warning in copyResult.warnings) {
      log.w(warning);
      stderr.writeln('Warning: $warning');
    }

    if (copyResult.hasWarnings && copyResult.totalCopied == 0) {
      exitCode = 1;
    }
  } on FileSystemException catch (error, stackTrace) {
    log.e('Failed to index "$folder".', error: error, stackTrace: stackTrace);
    stderr.writeln('Failed to index "$folder": ${error.message}');
    exitCode = 1;
  }
}
