import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/src/data/models/code_segment.dart';
import 'package:ft_file_sorter/src/logic/services/filename_parser_service.dart';

void main() {
  late FilenameParserService parserService;
  late List<CodeSegment> defaultSegments;

  setUp(() {
    parserService = const FilenameParserService();
    defaultSegments = CodeSegment.createDefaultSegments();
  });

  tearDown(() {
    for (final segment in defaultSegments) {
      segment.dispose();
    }
  });

  group('FilenameParserService', () {
    test('extractBaseName handles multiple path formats and extensions correctly', () {
      expect(
        FilenameParserService.extractBaseName(
            r'C:\Users\Admin\Documents\CCCCCCCCCCCCCCCCCCCCCCCC1122RRR.xlsx'),
        'CCCCCCCCCCCCCCCCCCCCCCCC1122RRR',
      );
      expect(
        FilenameParserService.extractBaseName(
            '/home/user/downloads/sample_file.csv'),
        'sample_file',
      );
      expect(
        FilenameParserService.extractBaseName(
            r'"D:\Folder Name\my_custom_code.xls"'),
        'my_custom_code',
      );
      expect(
        FilenameParserService.extractBaseName('simple_name.txt'),
        'simple_name',
      );
      expect(
        FilenameParserService.extractBaseName('no_extension'),
        'no_extension',
      );
    });

    test('calculateExpectedLength computes correct length without delimiter', () {
      // 24 + 2 + 2 + 3 = 31
      final len = FilenameParserService.calculateExpectedLength(defaultSegments);
      expect(len, 31);
    });

    test('calculateExpectedLength computes correct length with delimiter', () {
      // 31 + 3 * 1 = 34
      final len = FilenameParserService.calculateExpectedLength(
        defaultSegments,
        delimiter: '_',
      );
      expect(len, 34);
    });

    test('parses default schema without delimiter successfully', () {
      // 24 'C's, 2 '1's, 2 '2's, 3 'R's
      const code = 'AAAAAAAAAAAAAAAAAAAAAAAA';
      const idx1 = '42';
      const idx2 = '99';
      const rev = 'B01';
      const fullPath = r'C:\Target\Directory\' '$code$idx1$idx2$rev.xlsx';

      final result = parserService.parseFilename(fullPath, defaultSegments);
      expect(result, isNotNull);
      expect(result!['code'], code);
      expect(result['idx1'], idx1);
      expect(result['idx2'], idx2);
      expect(result['rev'], rev);
    });

    test('parses with delimiter correctly', () {
      const code = 'AAAAAAAAAAAAAAAAAAAAAAAA';
      const idx1 = '01';
      const idx2 = '02';
      const rev = 'R03';
      const base = '$code-$idx1-$idx2-$rev';
      const fullPath = '/path/to/$base.csv';

      final result = parserService.parseFilename(
        fullPath,
        defaultSegments,
        delimiter: '-',
      );
      expect(result, isNotNull);
      expect(result!['code'], code);
      expect(result['idx1'], idx1);
      expect(result['idx2'], idx2);
      expect(result['rev'], rev);
    });

    test('parses with reordered segments', () {
      // Reverse order: rev (3), idx2 (2), idx1 (2), code (24)
      final reversedSegments = defaultSegments.reversed.toList();
      const rev = 'R01';
      const idx2 = '22';
      const idx1 = '11';
      const code = '123456789012345678901234';
      const fileName = '$rev$idx2$idx1$code.xlsx';

      final result = parserService.parseFilename(fileName, reversedSegments);
      expect(result, isNotNull);
      expect(result!['rev'], rev);
      expect(result['idx2'], idx2);
      expect(result['idx1'], idx1);
      expect(result['code'], code);
    });

    test('throws FilenameParserException on length mismatch', () {
      expect(
        () => parserService.parseFilename('SHORT.xlsx', defaultSegments),
        throwsA(isA<FilenameParserException>()),
      );
    });

    test('throws FilenameParserException on delimiter mismatch', () {
      const code = 'AAAAAAAAAAAAAAAAAAAAAAAA';
      const idx1 = '01';
      const idx2 = '02';
      const rev = 'R03';
      // Used '_' instead of '-'
      const base = '${code}_${idx1}_${idx2}_$rev';

      expect(
        () => parserService.parseFilename(base, defaultSegments, delimiter: '-'),
        throwsA(isA<FilenameParserException>()),
      );
    });

    test('tryParse returns failure result with descriptive message on error', () {
      final res = parserService.tryParse('bad_len.xlsx', defaultSegments);
      expect(res.isSuccess, isFalse);
      expect(res.data, isNull);
      expect(res.errorMessage, isNotNull);
      expect(res.errorMessage, contains('expected 31 characters'));
    });
  });
}
