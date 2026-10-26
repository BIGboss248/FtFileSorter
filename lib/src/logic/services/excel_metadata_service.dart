import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import '../../data/models/excel_file_metadata.dart';

/// Service responsible for loading and extracting metadata and columns from Excel spreadsheets.
class ExcelMetadataService {
  const ExcelMetadataService();

  /// Parse the Excel file at [filePath] and inspect the specified [sheetName] (or first sheet by default).
  Future<ExcelFileMetadata> parseExcelFile(
    String filePath, {
    String? sheetName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Excel file does not exist', filePath);
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheets = excel.tables.keys.toList();
    if (sheets.isEmpty) {
      throw const FormatException('The provided Excel file has no worksheets.');
    }

    final targetSheetName = (sheetName != null && sheets.contains(sheetName))
        ? sheetName
        : sheets.first;

    final sheet = excel.tables[targetSheetName];
    if (sheet == null) {
      throw FormatException('Worksheet "$targetSheetName" could not be read.');
    }

    final maxCols = sheet.maxColumns;
    final maxRows = sheet.maxRows;

    final List<ExcelColumnInfo> columns = [];
    final List<List<String>> previewRows = [];
    final List<List<String>> allRows = [];

    // Extract headers from Row 0
    for (var colIdx = 0; colIdx < maxCols; colIdx++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 0),
      );
      final rawVal = cell.value?.toString().trim() ?? '';
      final letter = ExcelFileMetadata.getColumnLetter(colIdx);
      final headerText = rawVal.isNotEmpty ? rawVal : letter;

      columns.add(
        ExcelColumnInfo(
          index: colIdx,
          letter: letter,
          header: headerText,
        ),
      );
    }

    // Extract all data rows (starting from row 1)
    for (var rowIdx = 1; rowIdx < maxRows; rowIdx++) {
      final List<String> rowData = [];
      for (var colIdx = 0; colIdx < maxCols; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx),
        );
        rowData.add(cell.value?.toString().trim() ?? '');
      }
      allRows.add(rowData);
      if (previewRows.length < 5) {
        previewRows.add(rowData);
      }
    }

    // Detect the most likely Document Code column
    final autoDetectedIndex = _detectDocCodeColumnIndex(sheet, columns, maxRows);

    return ExcelFileMetadata(
      filePath: filePath,
      fileName: p.basename(filePath),
      sheetNames: sheets,
      selectedSheet: targetSheetName,
      totalRows: maxRows,
      totalColumns: maxCols,
      columns: columns,
      autoDetectedDocCodeColumnIndex: autoDetectedIndex,
      previewRows: previewRows,
      allRows: allRows,
    );
  }

  /// Rule-based detection of the document code column:
  /// 1. Persian/English header matches: 'شماره مدرک', 'کد مدرک', 'doc code', 'document number', 'drawing no'
  /// 2. Value pattern scanning: Column where rows frequently have 18-character alphanumeric strings
  int? _detectDocCodeColumnIndex(
    Sheet sheet,
    List<ExcelColumnInfo> columns,
    int maxRows,
  ) {
    if (columns.isEmpty) return null;

    // Phase 1: Header match
    final primaryKeywords = [
      'شماره مدرک',
      'شماره مدرك',
      'کد مدرک',
      'كد مدرك',
      'document code',
      'doc code',
      'document number',
      'doc number',
      'doc no',
      'drawing no',
    ];

    for (final col in columns) {
      final lowerHeader = col.header.toLowerCase();
      for (final kw in primaryKeywords) {
        if (lowerHeader.contains(kw)) {
          return col.index;
        }
      }
    }

    // Phase 2: Value sampling (check up to first 25 rows for 18-char uppercase alphanumeric patterns)
    final docCodeRegex = RegExp(r'^[A-Z0-9]{15,25}$');
    int bestColumnIndex = -1;
    int maxPatternMatches = 0;

    final sampleRowCount = maxRows > 25 ? 25 : maxRows;
    for (final col in columns) {
      int matchCount = 0;
      for (var r = 1; r < sampleRowCount; r++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col.index, rowIndex: r),
        );
        final val = cell.value?.toString().trim() ?? '';
        if (val.isNotEmpty && docCodeRegex.hasMatch(val)) {
          matchCount++;
        }
      }
      if (matchCount > maxPatternMatches) {
        maxPatternMatches = matchCount;
        bestColumnIndex = col.index;
      }
    }

    if (maxPatternMatches >= 2 && bestColumnIndex != -1) {
      return bestColumnIndex;
    }

    return null;
  }
}
