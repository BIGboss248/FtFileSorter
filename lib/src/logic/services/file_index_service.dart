import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/logging/app_logger.dart';
import '../../data/models/duplicate_code_group.dart';
import '../../data/models/indexed_file.dart';

/// Result of copying one file: its destination path and whether it was written.
typedef _CopyOutcome = ({String? target, bool copied});

/// Destination decision for one file: where it goes and whether to copy it.
typedef _TargetDecision = ({String target, bool copy});

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

  /// Document codes shared by two or more files, sorted by code.
  ///
  /// Only complete 18-character codes qualify, so short names such as `T2404`
  /// are never mistaken for duplicate documents.
  List<DuplicateCodeGroup> get duplicateCodeGroups =>
      DuplicateCodeGroup.fromFiles(files);

  /// Extensions (without the dot, lowercased) found for each document type.
  ///
  /// Types and their extension sets are sorted, so the result can drive the
  /// file-type rules editor without extra ordering work.
  Map<String, Set<String>> get extensionsByDocumentType {
    final grouped = <String, Set<String>>{};

    for (final file in files) {
      if (!file.hasDocumentType) continue;

      final extension = file.extension.startsWith('.')
          ? file.extension.substring(1).toLowerCase()
          : file.extension.toLowerCase();
      if (extension.isEmpty) continue;

      grouped
          .putIfAbsent(file.documentTypeCode, () => <String>{})
          .add(extension);
    }

    final types = grouped.keys.toList()..sort();
    return {
      for (final type in types) type: (grouped[type]!.toList()..sort()).toSet(),
    };
  }

  /// Total number of files that belong to a [duplicateCodeGroups] entry.
  int get duplicateFileCount =>
      duplicateCodeGroups.fold(0, (sum, group) => sum + group.fileCount);
}

/// Outcome of copying indexed files into a destination, either duplicate-code
/// groups only or every file sorted by document code.
class DuplicateCopyResult {
  /// Folder that receives the no-code files when [copyFilesByCode] is used.
  static const String noCodeFolderName = 'no_code';

  /// Root folder that received the per-code folders.
  final String destinationRoot;

  /// Complete document codes shared by two or more files, sorted by code.
  final List<DuplicateCodeGroup> groups;

  /// Destination paths of the files that were copied during this run.
  final List<String> copiedFiles;

  /// Unique-code files that were copied directly into [destinationRoot].
  final List<String> looseFiles;

  /// Destination paths of the files copied into
  /// `<destinationRoot>/[noCodeFolderName]` because their names are shorter
  /// than a complete document code.
  final List<String> noCodeFiles;

  /// Files that were already present and identical, and therefore skipped.
  final List<String> skippedFiles;

  /// Maps each source full path to the destination path that now holds it.
  ///
  /// Includes files that were already up to date, so the CSV can record where
  /// every copied file lives. Files that were not part of the copy are absent.
  final Map<String, String> copiedToBySource;

  /// Codes or files that could not be copied.
  final List<String> warnings;

  const DuplicateCopyResult({
    required this.destinationRoot,
    required this.groups,
    this.copiedFiles = const [],
    this.looseFiles = const [],
    this.noCodeFiles = const [],
    this.skippedFiles = const [],
    this.copiedToBySource = const {},
    this.warnings = const [],
  });

  /// Number of code folders that were created.
  int get totalGroups => groups.length;

  /// Number of files written during this run.
  int get totalCopied => copiedFiles.length;

  /// Number of unique-code files copied straight into [destinationRoot].
  int get totalLoose => looseFiles.length;

  /// Number of files copied into the no-code folder.
  int get totalNoCode => noCodeFiles.length;

  /// Number of files that were already up to date.
  int get totalSkipped => skippedFiles.length;

  /// Whether any code or file could not be copied.
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Index rows read back from a CSV produced by the File Indexer.
class CsvIndexData {
  /// Indexed files in CSV row order.
  final List<IndexedFile> files;

  /// Source full path -> destination path recorded in the `Copied To` column.
  final Map<String, String> copiedTo;

  const CsvIndexData({required this.files, this.copiedTo = const {}});

  /// Number of rows that were read.
  int get totalFiles => files.length;
}

/// Outcome of moving copied files that are not allowed for their document type.
class TrashResult {
  /// Destination root that was cleaned up.
  final String destinationRoot;

  /// Folder that received the undesired files: `<destinationRoot>/trash`.
  final String trashRoot;

  /// Source full path -> final path inside the trash folder.
  final Map<String, String> movedTo;

  /// Files that could not be moved.
  final List<String> warnings;

  const TrashResult({
    required this.destinationRoot,
    required this.trashRoot,
    this.movedTo = const {},
    this.warnings = const [],
  });

  /// Number of files that ended up in the trash folder.
  int get totalMoved => movedTo.length;

  /// Whether any file could not be moved.
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Outcome of flattening single-file folders in a copy destination.
class FlattenResult {
  /// Destination root whose subfolders were flattened.
  final String destinationRoot;

  /// Old destination path -> new path directly in [destinationRoot].
  final Map<String, String> movedTo;

  /// Folders that were deleted because their only file was moved out.
  final List<String> removedFolders;

  /// Files or folders that could not be flattened.
  final List<String> warnings;

  const FlattenResult({
    required this.destinationRoot,
    this.movedTo = const {},
    this.removedFolders = const [],
    this.warnings = const [],
  });

  /// Number of files moved into the destination root.
  int get totalMoved => movedTo.length;

  /// Number of folders that were removed.
  int get totalRemoved => removedFolders.length;

  /// Whether any folder could not be flattened.
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Recursively indexes every file below a folder and exports the result as CSV.
///
/// The service is deliberately free of Flutter imports so it can also be driven
/// from a plain Dart script or a unit test.
class FileIndexService {
  const FileIndexService();

  static final _log = createLogger('FileIndexService');

  /// Column order used by [buildCsv] and [writeCsv]. The first column is the
  /// 1-based row number so exported indexes line up with the table. The last
  /// column records where the copy step placed the file, when it ran.
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
    'Copied To',
  ];

  /// Name of the `Copied To` column inside [csvHeaders].
  static const String copiedToHeader = 'Copied To';

  /// Folder names that are never descended into unless [includeHidden] is true.
  static const Set<String> _ignoredDirectoryNames = {
    'System Volume Information',
    r'$RECYCLE.BIN',
  };

  /// Folder inside a copy destination that receives disallowed files.
  static const String _trashFolderName = 'trash';

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
  ///
  /// [copiedTo] maps a source full path to the destination recorded by a copy
  /// run. Missing entries leave the `Copied To` column empty.
  String buildCsv(
    List<IndexedFile> files, {
    Map<String, String> copiedTo = const {},
  }) {
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
        copiedTo[file.fullPath] ?? '',
      ];
      buffer
        ..write(row.map(escapeCsvValue).join(','))
        ..write('\r\n');

      _log.t('CSV row ${index + 1}: ${file.fileName}');
    }

    _log.d(
      'CSV built: ${buffer.length} character(s) for ${files.length} row(s), '
      '${copiedTo.length} copy destination(s).',
    );
    return buffer.toString();
  }

  /// Writes [files] as CSV to [destinationPath], creating parent folders when
  /// necessary. Returns the normalized path that was written.
  Future<String> writeCsv(
    String destinationPath,
    List<IndexedFile> files, {
    bool includeBom = true,
    Map<String, String> copiedTo = const {},
  }) async {
    _log.i(
      'Writing CSV: path="$destinationPath", rows=${files.length}, '
      'includeBom=$includeBom, copiedTo=${copiedTo.length}',
    );

    final destination = File(destinationPath);

    try {
      await destination.parent.create(recursive: true);
      _log.t('Ensured CSV parent directory exists: ${destination.parent.path}');

      final content = buildCsv(files, copiedTo: copiedTo);
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

  /// Reads a CSV produced by [writeCsv].
  ///
  /// Legacy files without a `Copied To` column are accepted; their copy map is
  /// simply empty. Throws a [FormatException] when the file is empty or lacks
  /// the `Full Path` column.
  Future<CsvIndexData> readCsv(String path) async {
    _log.d('Reading CSV: "$path".');
    final content = await File(path).readAsString(encoding: utf8);
    final data = parseCsv(content);
    _log.i(
      'CSV read: "$path" (${data.totalFiles} row(s), '
      '${data.copiedTo.length} copy destination(s)).',
    );
    return data;
  }

  /// Parses CSV [content] written by [buildCsv] into index rows.
  static CsvIndexData parseCsv(String content) {
    final normalized = content.startsWith('\uFEFF')
        ? content.substring(1)
        : content;
    final rows = _parseCsvRows(normalized);
    if (rows.isEmpty) {
      throw const FormatException('CSV is empty.');
    }

    final headers = rows.first
        .map((header) => header.trim().toLowerCase())
        .toList(growable: false);

    int indexOf(String header) => headers.indexOf(header.toLowerCase());

    final fullPathIndex = indexOf('Full Path');
    if (fullPathIndex < 0) {
      throw const FormatException('CSV is missing the "Full Path" column.');
    }

    final nameIndex = indexOf('File Name');
    final typeIndex = indexOf('Document Type');
    final codeIndex = indexOf('Document Code');
    final directoryIndex = indexOf('Directory');
    final sizeIndex = indexOf('Size (Bytes)');
    final modifiedIndex = indexOf('Modified');
    final copiedIndex = indexOf(copiedToHeader);

    String valueAt(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index] : '';

    final files = <IndexedFile>[];
    final copiedTo = <String, String>{};

    for (final row in rows.skip(1)) {
      if (row.every((value) => value.trim().isEmpty)) continue;

      final fullPath = valueAt(row, fullPathIndex).trim();
      if (fullPath.isEmpty) continue;

      final fileName = valueAt(row, nameIndex).trim();
      final directory = valueAt(row, directoryIndex).trim();
      final copied = valueAt(row, copiedIndex).trim();

      files.add(
        IndexedFile(
          fileName: fileName.isEmpty ? p.basename(fullPath) : fileName,
          directoryPath: directory.isEmpty ? p.dirname(fullPath) : directory,
          fullPath: fullPath,
          code: valueAt(row, codeIndex).trim().toUpperCase(),
          documentTypeCode: valueAt(row, typeIndex).trim().toUpperCase(),
          sizeInBytes: int.tryParse(valueAt(row, sizeIndex).trim()) ?? 0,
          lastModified: DateTime.tryParse(valueAt(row, modifiedIndex).trim()),
        ),
      );

      if (copied.isNotEmpty) copiedTo[fullPath] = copied;
    }

    return CsvIndexData(files: files, copiedTo: copiedTo);
  }

  /// Splits RFC 4180 CSV text into rows and fields.
  static List<List<String>> _parseCsvRows(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < content.length; i++) {
      final char = content[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }

      switch (char) {
        case '"':
          inQuotes = true;
        case ',':
          endField();
        case '\r':
          if (i + 1 < content.length && content[i + 1] == '\n') i++;
          endRow();
        case '\n':
          endRow();
        default:
          field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      endRow();
    }

    return rows;
  }

  /// Copies every file whose document code is shared with at least one other
  /// file into `<destinationRoot>/<document code>/`.
  ///
  /// This is the "bundle companions" workflow: revisions and formats of the
  /// same document end up side by side in a folder named after their common
  /// 18-character code. Source files are never moved or deleted.
  ///
  /// Existing files are not overwritten by default. Re-running the copy is
  /// idempotent: a destination file with the same size as its source is
  /// considered already copied, and files with clashing names inside a code
  /// folder are suffixed with ` (2)`, ` (3)`, and so on.
  ///
  /// [requireCompleteCode] keeps short file names from being grouped.
  Future<DuplicateCopyResult> copyDuplicateCodeGroups(
    List<IndexedFile> files, {
    required String destinationRoot,
    bool overwrite = false,
    bool requireCompleteCode = true,
  }) async {
    final trimmedRoot = destinationRoot.trim();
    if (trimmedRoot.isEmpty) {
      throw ArgumentError.value(
        destinationRoot,
        'destinationRoot',
        'must not be empty',
      );
    }

    final groups = DuplicateCodeGroup.fromFiles(
      files,
      requireCompleteCode: requireCompleteCode,
    );
    final destination = p.normalize(p.absolute(trimmedRoot));
    final fileCount = groups.fold(0, (sum, group) => sum + group.fileCount);

    _log.i(
      'Copying ${groups.length} duplicate document-code group(s) '
      '($fileCount file(s)) to "$destination" (overwrite=$overwrite).',
    );

    final copied = <String>[];
    final skipped = <String>[];
    final warnings = <String>[];
    final copiedTo = <String, String>{};
    final reservedNames = <String, Set<String>>{};

    for (final group in groups) {
      final folderName = _sanitizeFolderName(group.code);
      if (folderName.isEmpty) {
        warnings.add(
          'Skipped document code "${group.code}": it has no usable folder name.',
        );
        continue;
      }

      final groupRoot = p.join(destination, folderName);
      final reserved = reservedNames.putIfAbsent(
        folderName.toLowerCase(),
        () => <String>{},
      );

      if (!await _ensureDirectory(groupRoot, warnings)) continue;

      for (final file in group.files) {
        final outcome = await _copyInto(
          file: file,
          targetDirectory: groupRoot,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        final target = outcome.target;
        if (target != null) {
          copiedTo[file.fullPath] = target;
          if (outcome.copied) copied.add(target);
        }
      }
    }

    _log.i(
      'Duplicate copy finished: ${copied.length} copied, '
      '${skipped.length} already up to date, ${warnings.length} warning(s), '
      'destination "$destination".',
    );

    return DuplicateCopyResult(
      destinationRoot: destination,
      groups: groups,
      copiedFiles: copied,
      skippedFiles: skipped,
      copiedToBySource: copiedTo,
      warnings: warnings,
    );
  }

  /// Copies every indexed file into [destinationRoot], sorted by document code:
  ///
  /// * a complete 18-character code shared by two or more files gets its own
  ///   folder: `<destinationRoot>/<document code>/`;
  /// * a complete code that belongs to a single file is copied directly into
  ///   [destinationRoot] without a folder of its own;
  /// * files whose names are shorter than a complete code go into
  ///   `<destinationRoot>/no_code/`.
  ///
  /// Sources are copied, never moved or deleted. Existing destination files are
  /// kept unless [overwrite] is true, and re-running the copy is idempotent.
  Future<DuplicateCopyResult> copyFilesByCode(
    List<IndexedFile> files, {
    required String destinationRoot,
    bool overwrite = false,
  }) async {
    final trimmedRoot = destinationRoot.trim();
    if (trimmedRoot.isEmpty) {
      throw ArgumentError.value(
        destinationRoot,
        'destinationRoot',
        'must not be empty',
      );
    }

    final destination = p.normalize(p.absolute(trimmedRoot));
    final groups = DuplicateCodeGroup.fromFiles(files);
    final sharedCodes = {for (final group in groups) group.code};

    final looseSources = <IndexedFile>[];
    final noCodeSources = <IndexedFile>[];

    for (final file in files) {
      if (file.hasCompleteCode && sharedCodes.contains(file.code)) continue;
      if (file.hasCompleteCode) {
        looseSources.add(file);
      } else {
        noCodeSources.add(file);
      }
    }

    _log.i(
      'Copying ${files.length} file(s) by document code to "$destination": '
      '${groups.length} shared code folder(s), ${looseSources.length} unique '
      'file(s), ${noCodeSources.length} no-code file(s) '
      '(overwrite=$overwrite).',
    );

    final copied = <String>[];
    final loose = <String>[];
    final noCode = <String>[];
    final skipped = <String>[];
    final warnings = <String>[];
    final copiedTo = <String, String>{};
    final reservedNames = <String, Set<String>>{};

    // Shared codes first so their folders exist before loose files land in the
    // destination root and cannot collide with a folder name.
    for (final group in groups) {
      final folderName = _sanitizeFolderName(group.code);
      if (folderName.isEmpty) {
        warnings.add(
          'Skipped document code "${group.code}": it has no usable folder name.',
        );
        continue;
      }

      final groupRoot = p.join(destination, folderName);
      final reserved = reservedNames.putIfAbsent(
        folderName.toLowerCase(),
        () => <String>{},
      );

      if (!await _ensureDirectory(groupRoot, warnings)) continue;

      for (final file in group.files) {
        final outcome = await _copyInto(
          file: file,
          targetDirectory: groupRoot,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        final target = outcome.target;
        if (target != null) {
          copiedTo[file.fullPath] = target;
          if (outcome.copied) copied.add(target);
        }
      }
    }

    if (looseSources.isNotEmpty &&
        await _ensureDirectory(destination, warnings)) {
      final reserved = reservedNames.putIfAbsent('__root__', () => <String>{});

      for (final file in looseSources) {
        final outcome = await _copyInto(
          file: file,
          targetDirectory: destination,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        final target = outcome.target;
        if (target != null) {
          copiedTo[file.fullPath] = target;
          if (outcome.copied) {
            copied.add(target);
            loose.add(target);
          }
        }
      }
    }

    if (noCodeSources.isNotEmpty) {
      final noCodeRoot = p.join(
        destination,
        DuplicateCopyResult.noCodeFolderName,
      );

      if (await _ensureDirectory(noCodeRoot, warnings)) {
        final reserved = reservedNames.putIfAbsent(
          DuplicateCopyResult.noCodeFolderName.toLowerCase(),
          () => <String>{},
        );

        for (final file in noCodeSources) {
          final outcome = await _copyInto(
            file: file,
            targetDirectory: noCodeRoot,
            overwrite: overwrite,
            reservedNames: reserved,
            skipped: skipped,
            warnings: warnings,
          );
          final target = outcome.target;
          if (target != null) {
            copiedTo[file.fullPath] = target;
            if (outcome.copied) {
              copied.add(target);
              noCode.add(target);
            }
          }
        }
      }
    }

    _log.i(
      'Copy-by-code finished: ${copied.length} copied '
      '(${loose.length} loose, ${noCode.length} no-code), '
      '${skipped.length} already up to date, ${warnings.length} warning(s), '
      'destination "$destination".',
    );

    return DuplicateCopyResult(
      destinationRoot: destination,
      groups: groups,
      copiedFiles: copied,
      looseFiles: loose,
      noCodeFiles: noCode,
      skippedFiles: skipped,
      copiedToBySource: copiedTo,
      warnings: warnings,
    );
  }

  /// Moves copied files into `<destinationRoot>/trash/` when their extension is
  /// not allowed for their document type.
  ///
  /// [copiedToBySource] maps each source full path to the path it was copied to;
  /// only those destination files are considered, so unrelated files in the
  /// destination are never touched. Document types absent from
  /// [allowedExtensionsByDocumentType] are left alone, and an allowed set
  /// containing `*` keeps every extension for that type.
  ///
  /// The trash folder mirrors the relative layout of the copy destination
  /// (for example `trash/<document code>/<file>`), which keeps same-named files
  /// from different code folders apart. Re-running the cleanup is idempotent:
  /// when the trash already holds an identical file, the fresh destination copy
  /// is removed and the existing trash path is reported.
  Future<TrashResult> moveDisallowedFiles({
    required List<IndexedFile> files,
    required Map<String, String> copiedToBySource,
    required Map<String, Set<String>> allowedExtensionsByDocumentType,
    required String destinationRoot,
  }) async {
    final destination = p.normalize(p.absolute(destinationRoot));
    final trashRoot = p.join(destination, _trashFolderName);
    final filesBySource = {for (final file in files) file.fullPath: file};

    final movedTo = <String, String>{};
    final warnings = <String>[];

    _log.i(
      'Trash cleanup requested: ${copiedToBySource.length} copied file(s), '
      '${allowedExtensionsByDocumentType.length} document type rule(s), '
      'trash "$trashRoot".',
    );

    for (final entry in copiedToBySource.entries) {
      final file = filesBySource[entry.key];
      if (file == null) continue;

      final documentType = file.documentTypeCode.toUpperCase();
      if (documentType.isEmpty) continue;

      final allowed = allowedExtensionsByDocumentType[documentType];
      if (allowed == null || allowed.contains('*')) continue;

      final extension = file.extension.startsWith('.')
          ? file.extension.substring(1).toLowerCase()
          : file.extension.toLowerCase();
      if (allowed.contains(extension)) continue;

      final currentPath = entry.value;
      final relative = p.relative(currentPath, from: destination);
      final trashPrefix = 'trash${p.separator}';

      if (relative == 'trash' || relative.startsWith(trashPrefix)) {
        _log.t('Skipping file already in trash: "$currentPath".');
        movedTo[entry.key] = currentPath;
        continue;
      }
      if (p.isAbsolute(relative) || relative.startsWith('..')) {
        warnings.add(
          'Could not move "$currentPath" to trash: it is outside '
          '"$destination".',
        );
        continue;
      }

      final targetPath = p.join(trashRoot, relative);
      final source = File(currentPath);
      final target = File(targetPath);

      if (!await source.exists()) {
        _log.w('Cannot move missing copied file to trash: "$currentPath".');
        warnings.add(
          'Could not move "$currentPath" to trash: the file no longer exists.',
        );
        continue;
      }

      try {
        await target.parent.create(recursive: true);

        if (await target.exists() &&
            await target.length() == await source.length()) {
          // Already trashed in an earlier run; drop the fresh copy.
          await source.delete();
          movedTo[entry.key] = targetPath;
          _log.t('Already in trash: "$targetPath".');
          continue;
        }

        await source.copy(targetPath);
        await source.delete();
        movedTo[entry.key] = targetPath;
        _log.t('Moved to trash: "$currentPath" -> "$targetPath".');
      } on FileSystemException catch (error) {
        _log.w('Could not move file to trash: "$currentPath"', error: error);
        warnings.add(
          'Could not move "$currentPath" to trash: ${error.message}',
        );
      }
    }

    _log.i(
      'Trash cleanup finished: ${movedTo.length} file(s) moved, '
      '${warnings.length} warning(s).',
    );

    return TrashResult(
      destinationRoot: destination,
      trashRoot: trashRoot,
      movedTo: movedTo,
      warnings: warnings,
    );
  }

  /// Moves files out of folders that ended up holding a single file.
  ///
  /// Only the direct children of [destinationRoot] are inspected. When such a
  /// folder contains exactly one file, the file is moved into
  /// [destinationRoot] and the now-empty folder is deleted. Folders holding
  /// several files, no files, or a single subfolder are left untouched.
  ///
  /// The `trash` folder is never touched, so trashed files stay trashed, and
  /// dot-prefixed folders are skipped. Name clashes are resolved with
  /// ` (2)`, ` (3)`, ... exactly like the copy step, so no file is ever
  /// overwritten. Re-running the step is idempotent.
  Future<FlattenResult> flattenSingleFileFolders({
    required String destinationRoot,
  }) async {
    final trimmedRoot = destinationRoot.trim();
    if (trimmedRoot.isEmpty) {
      throw ArgumentError.value(
        destinationRoot,
        'destinationRoot',
        'must not be empty',
      );
    }

    final destination = p.normalize(p.absolute(trimmedRoot));
    final movedTo = <String, String>{};
    final removedFolders = <String>[];
    final warnings = <String>[];

    final rootType = await FileSystemEntity.type(
      destination,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      _log.i(
        'Flatten skipped: destination "$destination" does not exist or is '
        'not a folder.',
      );
      return FlattenResult(destinationRoot: destination);
    }

    _log.i('Flattening single-file folders in "$destination".');

    final List<FileSystemEntity> entries;
    try {
      entries = await Directory(destination).list(followLinks: false).toList();
    } on FileSystemException catch (error) {
      _log.w('Could not list destination "$destination".', error: error);
      return FlattenResult(
        destinationRoot: destination,
        warnings: ['Could not list "$destination": ${error.message}'],
      );
    }

    final folders = entries.whereType<Directory>().toList()
      ..sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );

    final reservedNames = <String>{};

    for (final folder in folders) {
      final folderName = p.basename(folder.path);
      if (folderName.toLowerCase() == _trashFolderName) {
        _log.t('Flatten skipped trash folder: "${folder.path}".');
        continue;
      }
      if (folderName.startsWith('.')) continue;

      final List<FileSystemEntity> contents;
      try {
        contents = await folder.list(followLinks: false).toList();
      } on FileSystemException catch (error) {
        _log.w('Could not inspect folder: "${folder.path}".', error: error);
        warnings.add('Could not inspect "${folder.path}": ${error.message}');
        continue;
      }

      if (contents.length != 1) continue;

      final only = contents.single;
      if (only is! File) continue;

      final target = await _resolveFlattenTarget(
        destination,
        p.basename(only.path),
        reservedNames,
      );

      try {
        await only.rename(target);
      } on FileSystemException catch (error) {
        _log.w('Could not move file out of "${folder.path}".', error: error);
        warnings.add(
          'Could not move "${only.path}" to "$target": ${error.message}',
        );
        continue;
      }

      movedTo[p.normalize(only.path)] = p.normalize(target);
      _log.t('Flattened "${only.path}" -> "$target".');

      try {
        await folder.delete();
        removedFolders.add(p.normalize(folder.path));
        _log.t('Removed emptied folder "${folder.path}".');
      } on FileSystemException catch (error) {
        _log.w(
          'Could not remove emptied folder: "${folder.path}".',
          error: error,
        );
        warnings.add(
          'Could not remove emptied folder "${folder.path}": ${error.message}',
        );
      }
    }

    _log.i(
      'Flatten finished: ${movedTo.length} file(s) moved, '
      '${removedFolders.length} folder(s) removed, '
      '${warnings.length} warning(s).',
    );

    return FlattenResult(
      destinationRoot: destination,
      movedTo: movedTo,
      removedFolders: removedFolders,
      warnings: warnings,
    );
  }

  /// Parses a document-type rule string such as `JC=dwg,pdf;JA=pdf`.
  ///
  /// Format: `DOCTYPE=ext1,ext2;DOCTYPE2=ext3`. Extensions are matched
  /// case-insensitively and may be written with or without a leading dot. An
  /// empty extension list (`JC=`) allows nothing, and `*` allows everything.
  /// Throws a [FormatException] for malformed entries.
  static Map<String, Set<String>> parseAllowedExtensions(String specification) {
    final result = <String, Set<String>>{};

    for (final rawEntry in specification.split(';')) {
      final entry = rawEntry.trim();
      if (entry.isEmpty) continue;

      final separator = entry.indexOf('=');
      if (separator <= 0) {
        throw FormatException('Expected DOCTYPE=ext1,ext2 in "$entry".');
      }

      final documentType = entry.substring(0, separator).trim().toUpperCase();
      if (documentType.isEmpty) {
        throw FormatException('Missing document type in "$entry".');
      }

      final extensions = result.putIfAbsent(documentType, () => <String>{});

      final rawExtensions = entry.substring(separator + 1);
      for (final rawExtension in rawExtensions.split(',')) {
        var extension = rawExtension.trim().toLowerCase();
        if (extension.isEmpty) continue;
        if (extension != '*') {
          while (extension.startsWith('.')) {
            extension = extension.substring(1);
          }
          if (extension.isEmpty) continue;
        }
        extensions.add(extension);
      }
    }

    if (result.isEmpty) {
      throw const FormatException('No document types were provided.');
    }

    return result;
  }

  /// Copies [file] into [targetDirectory], recording skips and failures.
  ///
  /// The returned target is set even when the file was already there, so callers
  /// can record where the copy lives. [copied] is false when the destination was
  /// already up to date.
  static Future<_CopyOutcome> _copyInto({
    required IndexedFile file,
    required String targetDirectory,
    required bool overwrite,
    required Set<String> reservedNames,
    required List<String> skipped,
    required List<String> warnings,
  }) async {
    final decision = await _resolveCopyTarget(
      targetDirectory,
      file,
      overwrite: overwrite,
      reservedNames: reservedNames,
    );
    final target = decision.target;

    if (!decision.copy) {
      _log.t('Skipping already copied file: ${file.fullPath} -> "$target".');
      reservedNames.add(p.basename(target).toLowerCase());
      skipped.add(file.fullPath);
      return (target: target, copied: false);
    }

    try {
      await File(file.fullPath).copy(target);
      reservedNames.add(p.basename(target).toLowerCase());
      _log.t('Copied "${file.fullPath}" -> "$target".');
      return (target: target, copied: true);
    } on FileSystemException catch (error) {
      _log.w('Could not copy file: ${file.fullPath}', error: error);
      warnings.add('Could not copy "${file.fullPath}": ${error.message}');
      return (target: null, copied: false);
    }
  }

  /// Creates [path] (and its parents), reporting failure through [warnings].
  static Future<bool> _ensureDirectory(
    String path,
    List<String> warnings,
  ) async {
    try {
      await Directory(path).create(recursive: true);
      return true;
    } on FileSystemException catch (error) {
      _log.w('Could not create folder: $path', error: error);
      warnings.add('Could not create folder "$path": ${error.message}');
      return false;
    }
  }

  /// Chooses the destination path for [file] inside [targetDirectory].
  ///
  /// [copy] is false when the destination already holds the file (same name and
  /// size, or the source itself), so the copy can be skipped without losing the
  /// destination path.
  static Future<_TargetDecision> _resolveCopyTarget(
    String targetDirectory,
    IndexedFile file, {
    required bool overwrite,
    required Set<String> reservedNames,
  }) async {
    final direct = p.join(targetDirectory, file.fileName);
    if (p.equals(p.normalize(file.fullPath), p.normalize(direct))) {
      return (target: direct, copy: false);
    }

    final directName = p.basename(direct).toLowerCase();
    final directFile = File(direct);
    final directType = await FileSystemEntity.type(direct, followLinks: false);
    final directExists = directType != FileSystemEntityType.notFound;
    final directIsFile = directType == FileSystemEntityType.file;

    if (!reservedNames.contains(directName) &&
        (!directExists || (overwrite && directIsFile))) {
      return (target: direct, copy: true);
    }

    if (directIsFile &&
        !overwrite &&
        await directFile.length() == file.sizeInBytes) {
      return (target: direct, copy: false);
    }

    final extension = p.extension(file.fileName);
    final baseName = p.basenameWithoutExtension(file.fileName);
    var counter = 2;

    while (true) {
      final candidateName = '$baseName ($counter)$extension';
      final candidate = p.join(targetDirectory, candidateName);
      final candidateFile = File(candidate);
      final candidateType = await FileSystemEntity.type(
        candidate,
        followLinks: false,
      );
      final candidateExists = candidateType != FileSystemEntityType.notFound;
      final candidateIsFile = candidateType == FileSystemEntityType.file;

      if (!reservedNames.contains(candidateName.toLowerCase()) &&
          (!candidateExists || (overwrite && candidateIsFile))) {
        return (target: candidate, copy: true);
      }

      if (candidateIsFile &&
          !overwrite &&
          await candidateFile.length() == file.sizeInBytes) {
        return (target: candidate, copy: false);
      }

      counter++;
    }
  }

  /// Chooses a free file name for a flattened file inside [directory].
  ///
  /// Returns `directory/<fileName>` when that name is free and otherwise
  /// appends ` (2)`, ` (3)`, ... before the extension, mirroring the naming
  /// used when two copied files clash. [reservedNames] prevents two flattened
  /// files from claiming the same name during one run.
  static Future<String> _resolveFlattenTarget(
    String directory,
    String fileName,
    Set<String> reservedNames,
  ) async {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    var counter = 1;

    while (true) {
      final candidateName = counter == 1
          ? fileName
          : '$baseName ($counter)$extension';
      final candidate = p.join(directory, candidateName);
      final lowerName = candidateName.toLowerCase();

      if (!reservedNames.contains(lowerName) &&
          await FileSystemEntity.type(candidate, followLinks: false) ==
              FileSystemEntityType.notFound) {
        reservedNames.add(lowerName);
        return candidate;
      }

      counter++;
    }
  }

  /// Replaces characters that are illegal in a folder name on Windows.
  static String _sanitizeFolderName(String value) {
    final name = value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    var trimmed = name;
    while (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
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
