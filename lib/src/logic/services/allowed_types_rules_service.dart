import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Shared document-type -> allowed file-extension rules.
///
/// The File Indexer screen edits this file and the CLI tool reads it, so the
/// assignments chosen in the UI are the ones used during copy cleanup.
///
/// The JSON is a flat map of document type to extensions:
///
/// ```json
/// {
///   "JC": ["dwg", "pdf"],
///   "JA": ["pdf"]
/// }
/// ```
///
/// An empty list (`"JC": []`) allows nothing, which moves every copied file of
/// that type to the trash. A document type that is absent keeps every file type.
class AllowedTypesRulesService {
  const AllowedTypesRulesService({this.filePath});

  /// Optional explicit file path. When omitted, [resolvePath] uses the shared
  /// application-data folder (see [resolvePathSync]).
  final String? filePath;

  /// File name used inside the shared configuration folders.
  static const String fileName = 'allowed_types.json';

  /// Environment override honoured by both the UI and the CLI.
  static const String environmentVariable = 'FTFILESORTER_RULES_FILE';

  /// Resolves the rules file location.
  ///
  /// Order: explicit [filePath], environment override, then the application-data
  /// folder (`%APPDATA%/FtFileSorter/allowed_types.json` on Windows, or a local
  /// `.ft_file_sorter` folder when APPDATA is unavailable).
  Future<String> resolvePath() async => resolvePathSync();

  /// Synchronous variant of [resolvePath], used by the UI editor.
  ///
  /// The default location is deliberately independent of the current working
  /// directory. The GUI app and the CLI are launched with different working
  /// directories (for example a packaged Windows app starts in
  /// `C:\Windows\System32`), so resolving through `Directory.current` made the
  /// editor and the CLI read and write *different* files and the rules chosen in
  /// the UI were silently ignored. Anchoring to the application-data folder
  /// guarantees both processes agree on one shared file.
  String resolvePathSync() {
    final explicit = filePath?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return p.normalize(p.absolute(explicit));
    }

    final fromEnvironment = Platform.environment[environmentVariable]?.trim();
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
      return p.normalize(p.absolute(fromEnvironment));
    }

    final appData = Platform.environment['APPDATA']?.trim();
    final base = (appData != null && appData.isNotEmpty)
        ? p.join(appData, 'FtFileSorter')
        : p.join(Directory.current.path, '.ft_file_sorter');

    return p.normalize(p.join(base, fileName));
  }

  /// Loads the rules. Missing or blank files produce an empty map.
  ///
  /// A nested `{ "allowedTypes": { ... } }` document is accepted as well as the
  /// flat map written by [save]. Values may be lists or comma-separated strings.
  Future<Map<String, Set<String>>> load() async => loadSync();

  /// Synchronous variant of [load], used by the UI editor.
  Map<String, Set<String>> loadSync() {
    final path = resolvePathSync();
    final file = File(path);
    if (!file.existsSync()) return <String, Set<String>>{};

    final content = file.readAsStringSync(encoding: utf8);
    if (content.trim().isEmpty) return <String, Set<String>>{};

    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw FormatException('$path: expected a JSON object.');
    }

    final rawRules = decoded['allowedTypes'];
    final rulesMap = rawRules is Map ? rawRules : decoded;
    final rules = <String, Set<String>>{};

    for (final entry in rulesMap.entries) {
      final documentType = entry.key.toString().trim().toUpperCase();
      if (documentType.isEmpty) continue;

      final value = entry.value;
      final extensions = <String>{};

      if (value is List) {
        for (final item in value) {
          final extension = _normalizeExtension(item.toString());
          if (extension.isNotEmpty) extensions.add(extension);
        }
      } else if (value is String) {
        for (final item in value.split(',')) {
          final extension = _normalizeExtension(item);
          if (extension.isNotEmpty) extensions.add(extension);
        }
      } else {
        throw FormatException(
          '$path: "$documentType" must be a list of extensions.',
        );
      }

      rules[documentType] = extensions;
    }

    return rules;
  }

  /// Writes [rules] as pretty JSON and returns the file path.
  Future<String> save(Map<String, Set<String>> rules) async => saveSync(rules);

  /// Synchronous variant of [save], used by the UI editor.
  String saveSync(Map<String, Set<String>> rules) {
    final path = resolvePathSync();
    final file = File(path);
    file.parent.createSync(recursive: true);

    final documentTypes = rules.keys.toList()..sort();
    final payload = <String, List<String>>{};

    for (final documentType in documentTypes) {
      final normalizedType = documentType.trim().toUpperCase();
      if (normalizedType.isEmpty) continue;

      final extensions =
          rules[documentType]!
              .map(_normalizeExtension)
              .where((extension) => extension.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      payload[normalizedType] = extensions;
    }

    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
      flush: true,
    );

    return path;
  }

  static String _normalizeExtension(String raw) {
    var value = raw.trim().toLowerCase();
    while (value.startsWith('.')) {
      value = value.substring(1);
    }
    return value;
  }
}
