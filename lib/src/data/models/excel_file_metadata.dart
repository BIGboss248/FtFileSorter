/// Represents a detected column from an Excel sheet.
class ExcelColumnInfo {
  final int index; // 0-based column index
  final String letter; // e.g., 'A', 'B', 'C'
  final String header; // Header text from first row or fallback letter

  const ExcelColumnInfo({
    required this.index,
    required this.letter,
    required this.header,
  });

  /// Formatted display label: "Col C: شماره مدرک" or "Col A"
  String get displayName {
    if (header.trim().isEmpty || header.trim() == letter) {
      return 'Column $letter';
    }
    return 'Column $letter ($header)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcelColumnInfo &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          letter == other.letter;

  @override
  int get hashCode => index.hashCode ^ letter.hashCode;
}

/// Metadata and extracted preview info from an Excel file.
class ExcelFileMetadata {
  final String filePath;
  final String fileName;
  final List<String> sheetNames;
  final String selectedSheet;
  final int totalRows;
  final int totalColumns;
  final List<ExcelColumnInfo> columns;
  final int? autoDetectedDocCodeColumnIndex;
  final List<List<String>> previewRows;
  final List<List<String>> allRows;

  const ExcelFileMetadata({
    required this.filePath,
    required this.fileName,
    required this.sheetNames,
    required this.selectedSheet,
    required this.totalRows,
    required this.totalColumns,
    required this.columns,
    this.autoDetectedDocCodeColumnIndex,
    this.previewRows = const [],
    this.allRows = const [],
  });

  /// Helper to convert 0-based column index to Excel column name (0 -> A, 2 -> C, 27 -> AB)
  static String getColumnLetter(int columnIndex) {
    var index = columnIndex;
    var result = '';
    while (index >= 0) {
      result = String.fromCharCode(65 + (index % 26)) + result;
      index = (index ~/ 26) - 1;
    }
    return result;
  }
}
