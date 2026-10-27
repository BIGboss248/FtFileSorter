import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/logging/app_logger.dart';
import '../../data/models/indexed_file.dart';

/// Outcome of indexing a folder tree.
class FileIndexResult {
  /// Folder that was scanned.
  final String rootPath;

  /// Indexed files, sorted by directory and then file name.
  final List<IndexedFile> files;

  /// Number of directories visited, including the root.
  final int scannedDirectories;

  /// Non-fatal problems encountered while walking the tree (for example a
  /// folder the process was not allowed to read).
  final List<String> warnings;

  const FileIndexResult({
    required this.rootPath,
    required this.files,
    this.scannedDirectories = 0,
    this.warnings = const [],
  });

  int get totalFiles => files.length;

  /// Total size of all indexed files in bytes.
  int get totalSizeInBytes =>
      files.fold(0, (sum, file) => sum + file.sizeInBytes);

  /// Distinct, non-empty document type codes, sorted alphabetically.
  List<String> get documentTypes {
    final types =
        files
            .map((file) => file.documentTypeCode)
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return types;
  }

  /// Distinct lowercased extensions, sorted alphabetically.
  List<String> get extensions {
    final values =
        files
            .map((file) => file.extension)
            .where((ext) => ext.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }
}

/// Recursively indexes every file below a folder and exports the result as CSV.
///
/// The service is deliberately free of Flutter imports so it can also be driven
/// from a plain Dart script or a unit test.
class FileIndexService {
  const FileIndexService();

  static final _log = createLogger('FileIndexService');

  /// Column order used by [buildCsv] and [writeCsv]. The first column is the
  /// 1-based row number so exported indexes line up with the table.
  static const List<String> csvHeaders = [
    'Index',
    'File Name',
    'Extension',
    'Document Type',
    'Document Code',
    'Directory',
    'Full Path',
    'Size (Bytes)',
    'Modified',
  ];

  /// Folder names that are never descended into unless [includeHidden] is true.
  static const Set<String> _ignoredDirectoryNames = {
    'System Volume Information',
    r'$RECYCLE.BIN',
  };

  /// OS-generated noise that is not part of the document archive.
  static const Set<String> _ignoredFileNames = {
    'thumbs.db',
    'ehthumbs.db',
    'desktop.ini',
  };

  /// Walks [rootPath] and returns every file it contains.
  ///
  /// When [recursive] is false only the direct children of [rootPath] are
  /// indexed. Hidden entries (dot-prefixed on POSIX, recycle-bin style folders
  /// on Windows) are skipped unless [includeHidden] is true.
  ///
  /// Paths listed in [excludePaths] are ignored. This lets a caller regenerate
  /// a CSV that lives inside the folder being indexed without indexing the
  /// previous export.
  ///
  /// Unreadable subdirectories are reported through
  /// [FileIndexResult.warnings] instead of aborting the whole scan.
  ///
  /// The file-system walk runs on a background isolate. Large or network
  /// folders can take seconds to enumerate, and doing that on the UI isolate
  /// would freeze the interface (and its progress spinner).
  Future<FileIndexResult> indexDirectory(
    String rootPath, {
    bool recursive = true,
    bool includeHidden = false,
    Set<String> excludePaths = const {},
  }) async {
    _log.d(
      'indexDirectory requested: path="$rootPath", recursive=$recursive, '
      'includeHidden=$includeHidden, excludePaths=${excludePaths.length}',
    );

    final root = Directory(p.absolute(rootPath));
    if (!await root.exists()) {
      _log.e('Cannot index "$rootPath": folder does not exist.');
      throw FileSystemException('Folder does not exist', rootPath);
    }

    final normalizedExcludes = excludePaths
        .map((path) => p.normalize(p.absolute(path)))
        .toList(growable: false);

    // Capture only plain values so the closure can be sent to the worker
    // isolate without dragging file-system wrappers along.
    final scanRoot = root.path;

    _log.t('Spawning background isolate to scan "$scanRoot".');

    final stopwatch = Stopwatch()..start();

    try {
      final result = await Isolate.run(
        () => _scanDirectory(
          scanRoot,
          recursive: recursive,
          includeHidden: includeHidden,
          excludedPaths: normalizedExcludes,
        ),
      );

      stopwatch.stop();
      _log.i(
        'Indexed ${result.totalFiles} file(s) in '
        '${result.scannedDirectories} folder(s) '
        '(${result.extensions.length} file type(s), '
        '${result.documentTypes.length} document type(s)) '
        'in ${stopwatch.elapsedMilliseconds} ms: ${result.rootPath}',
      );

      if (result.warnings.isNotEmpty) {
        _log.w(
          'Scan finished with ${result.warnings.length} warning(s): '
          '${result.rootPath}',
        );
      }

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log.e(
        'Indexing failed after ${stopwatch.elapsedMilliseconds} ms: '
        '"$rootPath"',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Synchronous scan executed inside the background isolate.
  static FileIndexResult _scanDirectory(
    String rootPath, {
    required bool recursive,
    required bool includeHidden,
    required List<String> excludedPaths,
  }) {
    final stopwatch = Stopwatch()..start();
    _log.d(
      'Worker scan started: "$rootPath" (recursive=$recursive, '
      'includeHidden=$includeHidden, excludedPaths=${excludedPaths.length})',
    );

    final root = Directory(rootPath);

    final files = <IndexedFile>[];
    final warnings = <String>[];
    final pending = <Directory>[root];
    var scannedDirectories = 0;

    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      scannedDirectories++;
      _log.t('Scanning directory: ${directory.path}');

      try {
        for (final entity in directory.listSync(followLinks: false)) {
          final name = p.basename(entity.path);

          if (entity is Directory) {
            if (!recursive) {
              _log.t('Skipping nested directory (recursive off): $name');
              continue;
            }
            if (!includeHidden && _isIgnoredDirectory(name)) {
              _log.t('Skipping ignored directory: ${entity.path}');
              continue;
            }
            pending.add(entity);
            continue;
          }

          if (entity is! File) {
            _log.t('Skipping non-file entity: ${entity.path}');
            continue;
          }

          if (!includeHidden && _isIgnoredFile(name)) {
            _log.t('Skipping ignored file: ${entity.path}');
            continue;
          }

          if (excludedPaths.isNotEmpty &&
              excludedPaths.any(
                (excluded) => p.equals(excluded, entity.path),
              )) {
            _log.t('Skipping excluded file: ${entity.path}');
            continue;
          }

          try {
            final stat = entity.statSync();
            final indexedFile = IndexedFile.fromPath(
              entity.path,
              sizeInBytes: stat.size,
              lastModified: stat.modified,
            );
            files.add(indexedFile);
            _log.t(
              'Indexed file: ${indexedFile.fileName} -> '
              'code="${indexedFile.code}", '
              'type="${indexedFile.documentTypeCode}", '
              'size=${indexedFile.sizeInBytes}B',
            );
          } on FileSystemException catch (error) {
            _log.w(
              'Could not read file metadata: ${entity.path}',
              error: error,
            );
            warnings.add('Skipped file "${entity.path}": ${error.message}');
          }
        }
      } on FileSystemException catch (error) {
        _log.w('Could not list folder: ${directory.path}', error: error);
        warnings.add('Skipped folder "${directory.path}": ${error.message}');
      }
    }

    files.sort(_compareFiles);
    stopwatch.stop();

    _log.d(
      'Worker scan finished in ${stopwatch.elapsedMilliseconds} ms: '
      '${files.length} file(s), $scannedDirectories folder(s), '
      '${warnings.length} warning(s)',
    );

    return FileIndexResult(
      rootPath: root.path,
      files: files,
      scannedDirectories: scannedDirectories,
      warnings: warnings,
    );
  }

  /// Serialises [files] to RFC 4180 CSV (CRLF line endings, quoted when
  /// needed) with a header row. The returned string has no byte-order mark;
  /// [writeCsv] adds one so Excel opens non-ASCII paths correctly.
  String buildCsv(List<IndexedFile> files) {
    _log.d('Building CSV for ${files.length} file(s).');

    final buffer = StringBuffer()
      ..write(csvHeaders.map(escapeCsvValue).join(','))
      ..write('\r\n');

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final row = [
        (index + 1).toString(),
        file.fileName,
        file.extension,
        file.documentTypeCode,
        file.code,
        file.directoryPath,
        file.fullPath,
        file.sizeInBytes.toString(),
        file.lastModified?.toIso8601String() ?? '',
      ];
      buffer
        ..write(row.map(escapeCsvValue).join(','))
        ..write('\r\n');

      _log.t('CSV row ${index + 1}: ${file.fileName}');
    }

    _log.d(
      'CSV built: ${buffer.length} character(s) for ${files.length} row(s).',
    );
    return buffer.toString();
  }

  /// Writes [files] as CSV to [destinationPath], creating parent folders when
  /// necessary. Returns the normalized path that was written.
  Future<String> writeCsv(
    String destinationPath,
    List<IndexedFile> files, {
    bool includeBom = true,
  }) async {
    _log.i(
      'Writing CSV: path="$destinationPath", rows=${files.length}, '
      'includeBom=$includeBom',
    );

    final destination = File(destinationPath);

    try {
      await destination.parent.create(recursive: true);
      _log.t('Ensured CSV parent directory exists: ${destination.parent.path}');

      final content = buildCsv(files);
      await destination.writeAsString(
        includeBom ? '\uFEFF$content' : content,
        encoding: utf8,
        flush: true,
      );

      final sizeInBytes = await destination.length();
      _log.i(
        'CSV written: ${destination.path} ($sizeInBytes bytes, '
        '${files.length} row(s))',
      );

      return destination.path;
    } catch (error, stackTrace) {
      _log.e(
        'Failed to write CSV to "$destinationPath"',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Quotes a CSV field when it contains a comma, quote, CR or LF.
  static String escapeCsvValue(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static bool _isIgnoredDirectory(String name) {
    return name.startsWith('.') || _ignoredDirectoryNames.contains(name);
  }

  static bool _isIgnoredFile(String name) {
    final lowerName = name.toLowerCase();
    return name.startsWith('.') ||
        lowerName.startsWith(r'~$') ||
        _ignoredFileNames.contains(lowerName);
  }

  static int _compareFiles(IndexedFile a, IndexedFile b) {
    final byDirectory = a.directoryPath.toLowerCase().compareTo(
      b.directoryPath.toLowerCase(),
    );
    if (byDirectory != 0) return byDirectory;
    return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
  }
}
