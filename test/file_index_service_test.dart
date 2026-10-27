import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/src/data/models/indexed_file.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('IndexedFile extraction', () {
    test('takes the first 18 characters of the name as the document code', () {
      expect(
        IndexedFile.extractCode('DNSSGM12000JCSS70001-0001.dwg'),
        equals('DNSSGM12000JCSS700'),
      );
      expect(
        IndexedFile.extractCode('DNSSGH13900JACD00100-0001.pdf'),
        equals('DNSSGH13900JACD001'),
      );
    });

    test('takes characters 12 and 13 as the document type', () {
      expect(
        IndexedFile.extractDocumentTypeCode('DNSSGM12000JCSS70001-0001.dwg'),
        equals('JC'),
      );
      expect(
        IndexedFile.extractDocumentTypeCode('DNSSGH13900JACD00100-0001.pdf'),
        equals('JA'),
      );
      expect(
        IndexedFile.extractDocumentTypeCode(
          'CNSSGM12000JCSS700-0001 (REV01).docx',
        ),
        equals('JC'),
      );
    });

    test('ignores revision and model suffixes beyond the 18th character', () {
      const plain = 'DNSSGM12000JCSS70001-0001.pdf';
      const suffixed = 'DNSSGM12000JCSS70001-0001-Model.pdf';

      expect(IndexedFile.extractCode(plain), equals('DNSSGM12000JCSS700'));
      expect(
        IndexedFile.extractCode(suffixed),
        equals(IndexedFile.extractCode(plain)),
      );
      expect(
        IndexedFile.extractDocumentTypeCode(suffixed),
        equals(IndexedFile.extractDocumentTypeCode(plain)),
      );
    });

    test('handles names shorter than 18 characters', () {
      expect(IndexedFile.extractCode('T2404.pdf'), equals('T2404'));
      expect(IndexedFile.extractDocumentTypeCode('T2404.pdf'), isEmpty);
    });

    test('uppercases code and type while preserving the file name', () {
      final file = IndexedFile.fromPath('/docs/dnssgm12000jcss70001-0001.dwg');

      expect(file.fileName, equals('dnssgm12000jcss70001-0001.dwg'));
      expect(file.code, equals('DNSSGM12000JCSS700'));
      expect(file.documentTypeCode, equals('JC'));
      expect(file.extension, equals('.dwg'));
      expect(file.hasCompleteCode, isTrue);
      expect(file.hasDocumentType, isTrue);
    });
  });

  group('FileIndexService.indexDirectory', () {
    late Directory tempDir;
    late FileIndexService service;

    setUp(() async {
      service = const FileIndexService();
      tempDir = await Directory.systemTemp.createTemp('ft_file_index_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'indexes nested files with name, type, folder, code and doc type',
      () async {
        final nested = Directory(p.join(tempDir.path, 'AS BUILT- DWG- JC-JA'));
        await nested.create();
        final drawing = File(
          p.join(nested.path, 'DNSSGM12000JCSS70001-0001.dwg'),
        );
        await drawing.writeAsString('dwg-content');

        await File(p.join(tempDir.path, 'T2404.pdf')).writeAsString('pdf');

        final result = await service.indexDirectory(tempDir.path);

        expect(result.totalFiles, equals(2));
        expect(result.scannedDirectories, equals(2));
        expect(result.documentTypes, equals(['JC']));
        expect(result.extensions, equals(['.dwg', '.pdf']));

        final indexedDrawing = result.files.firstWhere(
          (file) => file.fileName == 'DNSSGM12000JCSS70001-0001.dwg',
        );
        expect(indexedDrawing.code, equals('DNSSGM12000JCSS700'));
        expect(indexedDrawing.documentTypeCode, equals('JC'));
        expect(indexedDrawing.extension, equals('.dwg'));
        expect(indexedDrawing.directoryPath, equals(nested.path));
        expect(indexedDrawing.fullPath, equals(drawing.path));
        expect(indexedDrawing.sizeInBytes, greaterThan(0));
        expect(indexedDrawing.lastModified, isNotNull);

        final indexedPdf = result.files.firstWhere(
          (file) => file.fileName == 'T2404.pdf',
        );
        expect(indexedPdf.code, equals('T2404'));
        expect(indexedPdf.documentTypeCode, isEmpty);
        expect(indexedPdf.hasDocumentType, isFalse);
      },
    );

    test('only scans the root folder when recursive is false', () async {
      final nested = Directory(p.join(tempDir.path, 'nested'));
      await nested.create();
      await File(p.join(nested.path, 'inside.pdf')).writeAsString('x');
      await File(p.join(tempDir.path, 'outside.pdf')).writeAsString('x');

      final result = await service.indexDirectory(
        tempDir.path,
        recursive: false,
      );

      expect(result.totalFiles, equals(1));
      expect(result.files.single.fileName, equals('outside.pdf'));
      expect(result.scannedDirectories, equals(1));
    });

    test('skips dot-prefixed folders unless includeHidden is true', () async {
      final hidden = Directory(p.join(tempDir.path, '.git'));
      await hidden.create();
      await File(p.join(hidden.path, 'config')).writeAsString('x');
      await File(p.join(tempDir.path, 'visible.pdf')).writeAsString('x');

      final defaultResult = await service.indexDirectory(tempDir.path);
      expect(defaultResult.totalFiles, equals(1));
      expect(defaultResult.files.single.fileName, equals('visible.pdf'));

      final hiddenResult = await service.indexDirectory(
        tempDir.path,
        includeHidden: true,
      );
      expect(hiddenResult.totalFiles, equals(2));
    });

    test(
      'skips OS junk files such as Thumbs.db and Office lock files',
      () async {
        await File(p.join(tempDir.path, 'Thumbs.db')).writeAsString('x');
        await File(p.join(tempDir.path, r'~$report.docx')).writeAsString('x');
        await File(p.join(tempDir.path, 'document.pdf')).writeAsString('x');

        final result = await service.indexDirectory(tempDir.path);

        expect(result.totalFiles, equals(1));
        expect(result.files.single.fileName, equals('document.pdf'));
      },
    );

    test('sorts by directory, then case-insensitive file name', () async {
      await File(p.join(tempDir.path, 'b.pdf')).writeAsString('x');
      await File(p.join(tempDir.path, 'A.pdf')).writeAsString('x');
      final sub = Directory(p.join(tempDir.path, 'z-folder'));
      await sub.create();
      await File(p.join(sub.path, 'c.pdf')).writeAsString('x');

      final result = await service.indexDirectory(tempDir.path);

      expect(
        result.files.map((file) => file.fileName).toList(),
        equals(['A.pdf', 'b.pdf', 'c.pdf']),
      );
    });

    test('can exclude its own CSV output from the index', () async {
      final csv = File(p.join(tempDir.path, 'file_index.csv'));
      await csv.writeAsString('previous export');
      await File(p.join(tempDir.path, 'document.pdf')).writeAsString('x');

      final result = await service.indexDirectory(
        tempDir.path,
        excludePaths: {csv.path},
      );

      expect(result.totalFiles, equals(1));
      expect(result.files.single.fileName, equals('document.pdf'));
    });

    test('throws a FileSystemException when the folder is missing', () async {
      await expectLater(
        service.indexDirectory(p.join(tempDir.path, 'does-not-exist')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('CSV export', () {
    const service = FileIndexService();

    const trickyFile = IndexedFile(
      fileName: 'name,with,commas.dwg',
      directoryPath: r'C:\Docs\A "quoted" folder',
      fullPath: r'C:\Docs\A "quoted" folder\name,with,commas.dwg',
      code: 'NAME,WITH,COMMAS',
      documentTypeCode: 'DW',
      sizeInBytes: 2048,
    );

    test('writes the documented header row and escapes separators', () {
      final csv = service.buildCsv([trickyFile]);
      final lines = csv.split('\r\n');

      expect(lines.first, equals(FileIndexService.csvHeaders.join(',')));
      expect(lines[1], startsWith('1,'));
      expect(lines[1], contains('"name,with,commas.dwg"'));
      expect(lines[1], contains('"C:\\Docs\\A ""quoted"" folder"'));
      expect(lines[1], contains('.dwg'));
      expect(lines[1], contains('DW'));
      expect(lines[1], contains('NAME,WITH,COMMAS'));
    });

    test('numbers exported rows sequentially', () {
      final csv = service.buildCsv([trickyFile, trickyFile]);
      final lines = csv.split('\r\n');

      expect(lines[1], startsWith('1,'));
      expect(lines[2], startsWith('2,'));
    });

    test(
      'writes UTF-8 with a BOM and creates missing parent folders',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('ft_csv_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final destination = p.join(tempDir.path, 'out', 'file_index.csv');
        final writtenPath = await service.writeCsv(destination, [trickyFile]);

        expect(writtenPath, equals(destination));
        expect(File(destination).existsSync(), isTrue);

        final bytes = await File(destination).readAsBytes();
        expect(bytes.take(3).toList(), equals([0xEF, 0xBB, 0xBF]));

        final content = utf8.decode(bytes.skip(3).toList());
        expect(
          content,
          startsWith('${FileIndexService.csvHeaders.join(',')}\r\n'),
        );
        expect(content.trim().split('\r\n').length, equals(2));
      },
    );
  });

  group('Sample archive fixture', () {
    final sampleDirectory = Directory(p.join('text', 'fixtures', 'excel'));

    test(
      'indexes every sample file, including duplicate names in different folders',
      () async {
        final result = await const FileIndexService().indexDirectory(
          sampleDirectory.path,
        );

        expect(result.totalFiles, greaterThanOrEqualTo(130));
        expect(result.scannedDirectories, greaterThanOrEqualTo(5));
        expect(result.documentTypes, containsAll(['JC', 'JA']));
        expect(result.extensions, containsAll(['.dwg', '.pdf', '.docx']));

        final drawing = result.files.firstWhere(
          (file) => file.fileName == 'DNSSGM12000JCSS70001-0001.dwg',
        );
        expect(drawing.code, equals('DNSSGM12000JCSS700'));
        expect(drawing.documentTypeCode, equals('JC'));

        final pdf = result.files.firstWhere(
          (file) => file.fileName == 'DNSSGH13900JACD00100-0001.pdf',
        );
        expect(pdf.documentTypeCode, equals('JA'));

        // The same file name exists in more than one archive folder, so the
        // directory column must keep the rows distinct.
        final duplicateNames = result.files
            .where(
              (file) => file.fileName == 'DNSSGM12000JCSS72401-0001-Model.pdf',
            )
            .toList();
        expect(duplicateNames.length, greaterThan(1));
        expect(
          duplicateNames.map((file) => file.directoryPath).toSet().length,
          greaterThan(1),
        );
      },
      skip: sampleDirectory.existsSync()
          ? false
          : 'Sample archive not present at ${sampleDirectory.path}',
    );
  });
}
