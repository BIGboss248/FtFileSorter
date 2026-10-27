import 'package:path/path.dart' as p;

/// A single file discovered while indexing a folder tree.
///
/// Holds the file's identity (name, directory, extension) plus the two values
/// derived from the engineering filename convention:
///
/// * [code] — the first [codeLength] (18) characters of the file name.
/// * [documentTypeCode] — characters [typeStart] and [typeStart] + 1, i.e. the
///   12th and 13th characters of the file name when counting from 1.
///
/// Example: `DNSSGM12000JCSS70001-0001.dwg`
/// * code            -> `DNSSGM12000JCSS700`
/// * documentTypeCode -> `JC`
class IndexedFile {
  /// Number of characters kept for [code].
  static const int codeLength = 18;

  /// Zero-based index of the first character of [documentTypeCode].
  /// `11` is the 12th character when counting from 1.
  static const int typeStart = 11;

  /// Number of characters in [documentTypeCode].
  static const int typeLength = 2;

  /// File name including its extension, e.g. `T2404.pdf`.
  final String fileName;

  /// Absolute path of the folder that directly contains the file.
  final String directoryPath;

  /// Absolute path of the file itself.
  final String fullPath;

  final int sizeInBytes;

  /// Last modification timestamp, when the platform reports one.
  final DateTime? lastModified;

  /// Uppercased first [codeLength] characters of the file name.
  final String code;

  /// Uppercased characters [typeStart] .. [typeStart] + [typeLength] - 1.
  /// Empty when the file name is too short to contain them.
  final String documentTypeCode;

  const IndexedFile({
    required this.fileName,
    required this.directoryPath,
    required this.fullPath,
    required this.code,
    required this.documentTypeCode,
    this.sizeInBytes = 0,
    this.lastModified,
  });

  /// Builds an [IndexedFile] from an absolute [path], deriving the code and
  /// document type from the file name.
  factory IndexedFile.fromPath(
    String path, {
    int sizeInBytes = 0,
    DateTime? lastModified,
  }) {
    final fileName = p.basename(path);
    return IndexedFile(
      fileName: fileName,
      directoryPath: p.dirname(path),
      fullPath: path,
      sizeInBytes: sizeInBytes,
      lastModified: lastModified,
      code: extractCode(fileName),
      documentTypeCode: extractDocumentTypeCode(fileName),
    );
  }

  /// Lowercased extension including the dot, e.g. `.pdf`, or `''` when absent.
  String get extension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex).toLowerCase();
  }

  /// Whether the file name was long enough to yield a full 18-character code.
  bool get hasCompleteCode => code.length == codeLength;

  /// Whether a 2-character document type could be extracted.
  bool get hasDocumentType => documentTypeCode.length == typeLength;

  /// Extracts the uppercased first 18 characters of [fileName], ignoring the
  /// extension. Shorter names are returned in full.
  static String extractCode(String fileName) {
    final baseName = _baseName(fileName);
    final code = baseName.length <= codeLength
        ? baseName
        : baseName.substring(0, codeLength);
    return code.toUpperCase();
  }

  /// Extracts the uppercased 12th and 13th characters of [fileName], ignoring
  /// the extension. Returns `''` when the name is too short.
  static String extractDocumentTypeCode(String fileName) {
    final baseName = _baseName(fileName);
    if (baseName.length < typeStart + typeLength) return '';
    return baseName.substring(typeStart, typeStart + typeLength).toUpperCase();
  }

  /// Strips the extension, leaving dot-leading names such as `.gitignore`
  /// untouched.
  static String _baseName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }
}
