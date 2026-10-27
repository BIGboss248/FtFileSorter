import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/src/logic/services/allowed_types_rules_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AllowedTypesRulesService', () {
    late Directory tempDir;
    late String rulesPath;
    late AllowedTypesRulesService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ft_rules_');
      rulesPath = p.join(tempDir.path, 'allowed_types.json');
      service = AllowedTypesRulesService(filePath: rulesPath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves an explicit rules path', () async {
      expect(
        await service.resolvePath(),
        equals(p.normalize(p.absolute(rulesPath))),
      );
    });

    test('default location is independent of the working directory', () async {
      // Regression guard: the shared rules file must live somewhere both the
      // GUI app and the CLI resolve identically, so it cannot depend on
      // `Directory.current` (which differs between the two processes).
      const defaultService = AllowedTypesRulesService();
      final fromRepo = await defaultService.resolvePath();

      final probeDir = await Directory.systemTemp.createTemp('ft_cwd_probe_');
      final previous = Directory.current;
      try {
        Directory.current = probeDir.path;
        final fromProbe = await defaultService.resolvePath();
        expect(fromProbe, equals(fromRepo));
      } finally {
        Directory.current = previous.path;
        await probeDir.delete(recursive: true);
      }
    });

    test('missing file loads as empty rules', () async {
      expect(await service.load(), isEmpty);
    });

    test('saves normalized rules that load back unchanged', () async {
      await service.save({
        'jc': {'DWG', '.PDF'},
        'JA': {'*'},
        'CA': <String>{},
      });

      final raw = jsonDecode(await File(rulesPath).readAsString());
      expect(
        raw,
        equals({
          'CA': <String>[],
          'JA': <String>['*'],
          'JC': <String>['dwg', 'pdf'],
        }),
      );

      final loaded = await service.load();
      expect(loaded['JC'], equals({'dwg', 'pdf'}));
      expect(loaded['JA'], equals({'*'}));
      expect(loaded['CA'], isEmpty);
    });

    test('loads nested allowedTypes documents and comma values', () async {
      await File(rulesPath).writeAsString('''
{
  "version": 1,
  "allowedTypes": {
    "JC": [".dwg", "PDF"],
    "JA": "pdf, .dxf"
  }
}
''');

      final loaded = await service.load();

      expect(loaded['JC'], equals({'dwg', 'pdf'}));
      expect(loaded['JA'], equals({'pdf', 'dxf'}));
    });

    test('rejects malformed extension values', () async {
      await File(rulesPath).writeAsString('{"JC": 3}');

      await expectLater(service.load(), throwsFormatException);
    });

    test('rejects non-object JSON', () async {
      await File(rulesPath).writeAsString('["JC"]');

      await expectLater(service.load(), throwsFormatException);
    });
  });
}
