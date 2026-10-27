import 'dart:io';

import 'package:ft_file_sorter/core/logging/app_logger.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:path/path.dart' as p;

/// Indexes a folder and writes the CSV used by the File Indexer screen.
///
/// Usage:
///   `dart run tool/index_folder.dart <folder> [output.csv] [--no-recursive]`
///
/// When [output.csv] is omitted the file is written next to the scanned folder
/// as `file_index.csv`.
Future<void> main(List<String> arguments) async {
  final log = createLogger('index_folder');
  log.d('CLI arguments: $arguments');

  final flags = arguments.where((argument) => argument.startsWith('--'));
  final positional = arguments
      .where((argument) => !argument.startsWith('--'))
      .toList();

  if (positional.isEmpty) {
    log.e('Missing required <folder> argument.');
    stderr.writeln(
      'Usage: dart run tool/index_folder.dart <folder> [output.csv] '
      '[--no-recursive]',
    );
    exitCode = 64;
    return;
  }

  final folder = positional.first;
  final outputPath = positional.length > 1
      ? positional[1]
      : p.join(p.normalize(folder), 'file_index.csv');
  final recursive = !flags.contains('--no-recursive');

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
  } on FileSystemException catch (error, stackTrace) {
    log.e('Failed to index "$folder".', error: error, stackTrace: stackTrace);
    stderr.writeln('Failed to index "$folder": ${error.message}');
    exitCode = 1;
  }
}
