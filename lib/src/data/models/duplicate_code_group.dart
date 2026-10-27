import 'indexed_file.dart';

/// A set of indexed files that share the same 18-character document code.
///
/// Engineering archives often keep the same document in several formats or
/// revisions (`...-0001.dwg`, `...-0001.pdf`). Grouping by code makes those
/// companions visible and lets the indexer copy them into a folder named after
/// the code.
class DuplicateCodeGroup {
  /// Shared 18-character document code, uppercased.
  final String code;

  /// Files carrying [code], in the order they were indexed.
  final List<IndexedFile> files;

  const DuplicateCodeGroup({required this.code, required this.files});

  /// Number of files in this group.
  int get fileCount => files.length;

  /// Whether more than one file shares the code. Groups produced by
  /// [fromFiles] always satisfy this.
  bool get isDuplicate => files.length > 1;

  /// Groups [files] by [IndexedFile.code], keeping only codes shared by two or
  /// more files. Empty codes are always ignored.
  ///
  /// When [requireCompleteCode] is true (the default) only 18-character codes
  /// qualify, so short unrelated names such as `T2404` are not treated as
  /// duplicate documents.
  ///
  /// The returned groups are sorted by code; files inside a group keep the
  /// incoming order.
  static List<DuplicateCodeGroup> fromFiles(
    List<IndexedFile> files, {
    bool requireCompleteCode = true,
  }) {
    final grouped = <String, List<IndexedFile>>{};

    for (final file in files) {
      if (file.code.isEmpty) continue;
      if (requireCompleteCode && !file.hasCompleteCode) continue;
      grouped.putIfAbsent(file.code, () => <IndexedFile>[]).add(file);
    }

    final groups = <DuplicateCodeGroup>[
      for (final entry in grouped.entries)
        if (entry.value.length > 1)
          DuplicateCodeGroup(code: entry.key, files: entry.value),
    ]..sort((a, b) => a.code.compareTo(b.code));

    return groups;
  }
}
