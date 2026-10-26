import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/src/data/models/document_type_info.dart';
import 'package:ft_file_sorter/src/logic/services/document_code_parser_service.dart';

void main() {
  const service = DocumentCodeParserService();

  group('DocumentCodeParserService', () {
    test('returns empty analysis for empty or whitespace input', () {
      final result1 = service.analyze('');
      expect(result1.isEmpty, isTrue);
      expect(result1.totalLength, equals(0));
      expect(result1.isValidLength, isFalse);

      final result2 = service.analyze('   ');
      expect(result2.isEmpty, isTrue);
    });

    test('correctly deconstructs valid 18-character code', () {
      // PRJ1020300 (1-10) + DW (11-12) + 000101 (13-18) = 18 chars
      const code = 'PRJ1020300DW000101';
      final result = service.analyze(code);

      expect(result.isValidLength, isTrue);
      expect(result.totalLength, equals(18));
      expect(result.prefixCode, equals('PRJ1020300'));
      expect(result.documentTypeCode, equals('DW'));
      expect(result.suffixCode, equals('000101'));
      expect(result.hasDocumentType, isTrue);
      expect(result.documentTypeInfo?.title, equals('Engineering Drawing'));
      expect(result.targetFileTypes, containsAll(['.pdf', '.dwg', '.dxf']));
    });

    test('extracts code from full file paths and extensions', () {
      const windowsPath = r'C:\Users\Engineer\Downloads\PRJ1020300DW000101.pdf';
      final result = service.analyze(windowsPath);

      expect(result.sanitizedCode, equals('PRJ1020300DW000101'));
      expect(result.prefixCode, equals('PRJ1020300'));
      expect(result.documentTypeCode, equals('DW'));
      expect(result.suffixCode, equals('000101'));
      expect(result.isValidLength, isTrue);
    });

    test('handles partial input gracefully when typing under 10 chars', () {
      final result = service.analyze('PRJ102');
      expect(result.totalLength, equals(6));
      expect(result.prefixCode, equals('PRJ102'));
      expect(result.documentTypeCode, isEmpty);
      expect(result.hasDocumentType, isFalse);
      expect(result.isValidLength, isFalse);
      expect(result.statusMessage, contains('Enter at least 12 characters'));
    });

    test('identifies document type once characters 11 and 12 are entered', () {
      // 10 chars prefix + 2 chars doc type = 12 chars
      final result = service.analyze('PRJ1020300SP');
      expect(result.totalLength, equals(12));
      expect(result.prefixCode, equals('PRJ1020300'));
      expect(result.documentTypeCode, equals('SP'));
      expect(result.hasDocumentType, isTrue);
      expect(result.documentTypeInfo?.title, equals('Technical Specification'));
      expect(result.targetFileTypes, containsAll(['.pdf', '.docx', '.doc']));
      expect(result.isValidLength, isFalse); // Only 12 of 18 chars
      expect(result.statusMessage, contains('Enter 6 more character'));
    });

    test('maps common document types and their corresponding target file types', () {
      final dsResult = service.analyze('PRJ1020300DS000101');
      expect(dsResult.documentTypeCode, equals('DS'));
      expect(dsResult.documentTypeInfo?.title, equals('Equipment Data Sheet'));
      expect(dsResult.targetFileTypes, containsAll(['.pdf', '.xlsx', '.xls']));

      final caResult = service.analyze('PRJ1020300CA000101');
      expect(caResult.documentTypeCode, equals('CA'));
      expect(caResult.documentTypeInfo?.title, equals('Calculation Note'));
      expect(caResult.targetFileTypes, containsAll(['.pdf', '.xlsx', '.xls']));

      final elResult = service.analyze('PRJ1020300EL000101');
      expect(elResult.documentTypeCode, equals('EL'));
      expect(elResult.documentTypeInfo?.title, equals('Electrical Schematic'));
      expect(elResult.targetFileTypes, containsAll(['.pdf', '.dwg', '.dxf']));
    });

    test('falls back gracefully to custom document type for unknown 2-letter codes', () {
      final result = service.analyze('PRJ1020300ZZ000101');
      expect(result.documentTypeCode, equals('ZZ'));
      expect(result.documentTypeInfo?.title, contains('Custom Document Type (ZZ)'));
      expect(result.targetFileTypes, isNotEmpty);
    });

    test('flags inputs that exceed 18 characters', () {
      final result = service.analyze('PRJ1020300DW000101EXTRA');
      expect(result.isValidLength, isFalse);
      expect(result.totalLength, equals(23));
      expect(result.statusMessage, contains('exceeds 18 characters'));
    });
  });

  group('DocumentTypeInfo', () {
    test('resolves standard uppercase and lowercase codes', () {
      final info = DocumentTypeInfo.resolve('dw');
      expect(info.code, equals('DW'));
      expect(info.title, equals('Engineering Drawing'));
      expect(info.targetFileTypes, contains('.dwg'));
    });
  });
}
