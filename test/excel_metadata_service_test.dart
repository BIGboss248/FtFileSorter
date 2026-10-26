import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/src/data/models/excel_file_metadata.dart';
import 'package:ft_file_sorter/src/logic/services/excel_metadata_service.dart';

void main() {
  group('ExcelMetadataService & ExcelFileMetadata Tests', () {
    const service = ExcelMetadataService();

    test('getColumnLetter converts 0-based indices correctly', () {
      expect(ExcelFileMetadata.getColumnLetter(0), equals('A'));
      expect(ExcelFileMetadata.getColumnLetter(1), equals('B'));
      expect(ExcelFileMetadata.getColumnLetter(2), equals('C'));
      expect(ExcelFileMetadata.getColumnLetter(25), equals('Z'));
      expect(ExcelFileMetadata.getColumnLetter(26), equals('AA'));
      expect(ExcelFileMetadata.getColumnLetter(27), equals('AB'));
    });

    test('parses sample.xlsx metadata and auto-detects Column C (شماره مدرک)', () async {
      final metadata = await service.parseExcelFile(r'D:\Downloads\sample.xlsx');

      expect(metadata.fileName, equals('sample.xlsx'));
      expect(metadata.sheetNames, contains('Sheet1'));
      expect(metadata.selectedSheet, equals('Sheet1'));
      expect(metadata.totalRows, greaterThanOrEqualTo(19));
      expect(metadata.columns.isNotEmpty, isTrue);

      // Verify Column C (index 2) is auto-detected
      expect(metadata.autoDetectedDocCodeColumnIndex, equals(2));

      final docCodeCol = metadata.columns.firstWhere(
        (col) => col.index == metadata.autoDetectedDocCodeColumnIndex,
      );
      expect(docCodeCol.letter, equals('C'));
      expect(docCodeCol.header, contains('شماره مدرک'));
    });
  });
}
