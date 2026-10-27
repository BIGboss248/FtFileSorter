import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/logging/app_logger.dart';
import '../../data/models/duplicate_code_group.dart';
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

  /// Document codes shared by two or more files, sorted by code.
  ///
  /// Only complete 18-character codes qualify, so short names such as `T2404`
  /// are never mistaken for duplicate documents.
  List<DuplicateCodeGroup> get duplicateCodeGroups =>
      DuplicateCodeGroup.fromFiles(files);

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

  /// Codes or files that could not be copied.
  final List<String> warnings;

  const DuplicateCopyResult({
    required this.destinationRoot,
    required this.groups,
    this.copiedFiles = const [],
    this.looseFiles = const [],
    this.noCodeFiles = const [],
    this.skippedFiles = const [],
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
        final target = await _copyInto(
          file: file,
          targetDirectory: groupRoot,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        if (target != null) copied.add(target);
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
        final target = await _copyInto(
          file: file,
          targetDirectory: groupRoot,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        if (target != null) copied.add(target);
      }
    }

    if (looseSources.isNotEmpty &&
        await _ensureDirectory(destination, warnings)) {
      final reserved = reservedNames.putIfAbsent('__root__', () => <String>{});

      for (final file in looseSources) {
        final target = await _copyInto(
          file: file,
          targetDirectory: destination,
          overwrite: overwrite,
          reservedNames: reserved,
          skipped: skipped,
          warnings: warnings,
        );
        if (target != null) {
          copied.add(target);
          loose.add(target);
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
          final target = await _copyInto(
            file: file,
            targetDirectory: noCodeRoot,
            overwrite: overwrite,
            reservedNames: reserved,
            skipped: skipped,
            warnings: warnings,
          );
          if (target != null) {
            copied.add(target);
            noCode.add(target);
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
      warnings: warnings,
    );
  }

  /// Copies [file] into [targetDirectory], recording skips and failures.
  /// Returns the destination path, or `null` when nothing was written.
  static Future<String?> _copyInto({
    required IndexedFile file,
    required String targetDirectory,
    required bool overwrite,
    required Set<String> reservedNames,
    required List<String> skipped,
    required List<String> warnings,
  }) async {
    final target = await _resolveCopyTarget(
      targetDirectory,
      file,
      overwrite: overwrite,
      reservedNames: reservedNames,
    );

    if (target == null) {
      _log.t('Skipping already copied file: ${file.fullPath}');
      skipped.add(file.fullPath);
      return null;
    }

    try {
      await File(file.fullPath).copy(target);
      reservedNames.add(p.basename(target).toLowerCase());
      _log.t('Copied "${file.fullPath}" -> "$target".');
      return target;
    } on FileSystemException catch (error) {
      _log.w('Could not copy file: ${file.fullPath}', error: error);
      warnings.add('Could not copy "${file.fullPath}": ${error.message}');
      return null;
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

  /// Chooses the destination path for [file] inside [groupRoot], or `null` when
  /// the file is already there (or is its own destination).
  static Future<String?> _resolveCopyTarget(
    String targetDirectory,
    IndexedFile file, {
    required bool overwrite,
    required Set<String> reservedNames,
  }) async {
    final direct = p.join(targetDirectory, file.fileName);
    if (p.equals(p.normalize(file.fullPath), p.normalize(direct))) {
      return null;
    }

    final directName = p.basename(direct).toLowerCase();
    final directFile = File(direct);
    final directType = await FileSystemEntity.type(direct, followLinks: false);
    final directExists = directType != FileSystemEntityType.notFound;
    final directIsFile = directType == FileSystemEntityType.file;

    if (!reservedNames.contains(directName) &&
        (!directExists || (overwrite && directIsFile))) {
      return direct;
    }

    if (directIsFile &&
        !overwrite &&
        await directFile.length() == file.sizeInBytes) {
      return null;
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
        return candidate;
      }

      if (candidateIsFile &&
          !overwrite &&
          await candidateFile.length() == file.sizeInBytes) {
        return null;
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
