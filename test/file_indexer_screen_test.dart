import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/app_theme.dart';
import 'package:ft_file_sorter/src/data/models/duplicate_code_group.dart';
import 'package:ft_file_sorter/src/data/models/indexed_file.dart';
import 'package:ft_file_sorter/src/logic/services/allowed_types_rules_service.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:ft_file_sorter/src/presentation/screens/configuration_screen.dart';
import 'package:ft_file_sorter/src/presentation/screens/file_indexer_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Returns a canned result so the widget test does not touch the file system.
class _FakeIndexService extends FileIndexService {
  _FakeIndexService(this.result);

  final FileIndexResult result;

  @override
  Future<FileIndexResult> indexDirectory(
    String rootPath, {
    bool recursive = true,
    bool includeHidden = false,
    Set<String> excludePaths = const {},
  }) async {
    return result;
  }
}

/// Keeps the scan in flight until the test completes [completer], so the
/// loading state can be asserted.
class _PendingIndexService extends FileIndexService {
  final Completer<FileIndexResult> completer = Completer<FileIndexResult>();

  @override
  Future<FileIndexResult> indexDirectory(
    String rootPath, {
    bool recursive = true,
    bool includeHidden = false,
    Set<String> excludePaths = const {},
  }) {
    return completer.future;
  }
}

/// Invokes [onStart] at the exact moment the scan is requested so a test can
/// assert what the UI looked like before indexing began.
class _CallbackIndexService extends FileIndexService {
  _CallbackIndexService(this.result, {this.onStart});

  final FileIndexResult result;
  final VoidCallback? onStart;

  @override
  Future<FileIndexResult> indexDirectory(
    String rootPath, {
    bool recursive = true,
    bool includeHidden = false,
    Set<String> excludePaths = const {},
  }) async {
    onStart?.call();
    return result;
  }
}

/// Records the destination of a duplicate-code copy and returns a synthetic
/// result so widget tests never touch the file system.
class _FakeCopyService extends FileIndexService {
  _FakeCopyService(this.result, {this.trashResult, this.flattenResult});

  final FileIndexResult result;

  /// Synthetic cleanup result returned by [moveDisallowedFiles]. When `null`
  /// the fake reports an empty trash, keeping tests hermetic.
  final TrashResult? trashResult;

  /// Synthetic flatten result returned by [flattenSingleFileFolders]. When
  /// `null` the fake reports nothing flattened.
  final FlattenResult? flattenResult;
  String? copiedDestination;
  bool? copiedOverwrite;
  String? flattenedDestination;

  @override
  Future<FileIndexResult> indexDirectory(
    String rootPath, {
    bool recursive = true,
    bool includeHidden = false,
    Set<String> excludePaths = const {},
  }) async {
    return result;
  }

  @override
  Future<DuplicateCopyResult> copyDuplicateCodeGroups(
    List<IndexedFile> files, {
    required String destinationRoot,
    bool overwrite = false,
    bool requireCompleteCode = true,
  }) async {
    copiedDestination = destinationRoot;
    copiedOverwrite = overwrite;

    final groups = DuplicateCodeGroup.fromFiles(
      files,
      requireCompleteCode: requireCompleteCode,
    );

    return DuplicateCopyResult(
      destinationRoot: destinationRoot,
      groups: groups,
      copiedFiles: [
        for (final group in groups)
          for (final file in group.files) file.fullPath,
      ],
    );
  }

  @override
  Future<TrashResult> moveDisallowedFiles({
    required List<IndexedFile> files,
    required Map<String, String> copiedToBySource,
    required Map<String, Set<String>> allowedExtensionsByDocumentType,
    required String destinationRoot,
  }) async {
    return trashResult ??
        TrashResult(
          destinationRoot: destinationRoot,
          trashRoot: p.join(destinationRoot, 'trash'),
        );
  }

  @override
  Future<FlattenResult> flattenSingleFileFolders({
    required String destinationRoot,
  }) async {
    flattenedDestination = destinationRoot;
    return flattenResult ?? FlattenResult(destinationRoot: destinationRoot);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Widget buildTestableWidget(Widget child) {
    return AdaptiveTheme(
      light: AppTheme.lightTheme,
      dark: AppTheme.darkTheme,
      initial: AdaptiveThemeMode.light,
      builder: (theme, darkTheme) =>
          MaterialApp(theme: theme, darkTheme: darkTheme, home: child),
    );
  }

  FileIndexResult buildSampleResult() {
    return const FileIndexResult(
      rootPath: r'C:\Docs\AS BUILT',
      scannedDirectories: 3,
      files: [
        IndexedFile(
          fileName: 'DNSSGM12000JCSS70001-0001.dwg',
          directoryPath: r'C:\Docs\AS BUILT\DWG',
          fullPath: r'C:\Docs\AS BUILT\DWG\DNSSGM12000JCSS70001-0001.dwg',
          code: 'DNSSGM12000JCSS700',
          documentTypeCode: 'JC',
          sizeInBytes: 2048,
        ),
        IndexedFile(
          fileName: 'T2404.pdf',
          directoryPath: r'C:\Docs\AS BUILT\T2404',
          fullPath: r'C:\Docs\AS BUILT\T2404\T2404.pdf',
          code: 'T2404',
          documentTypeCode: '',
          sizeInBytes: 1024,
        ),
      ],
    );
  }

  FileIndexResult buildDuplicateResult() {
    return const FileIndexResult(
      rootPath: r'C:\Docs\AS BUILT',
      scannedDirectories: 2,
      files: [
        IndexedFile(
          fileName: 'DNSSGM12000JCSS70001-0001.dwg',
          directoryPath: r'C:\Docs\AS BUILT\DWG',
          fullPath: r'C:\Docs\AS BUILT\DWG\DNSSGM12000JCSS70001-0001.dwg',
          code: 'DNSSGM12000JCSS700',
          documentTypeCode: 'JC',
          sizeInBytes: 2048,
        ),
        IndexedFile(
          fileName: 'DNSSGM12000JCSS70001-0001.pdf',
          directoryPath: r'C:\Docs\AS BUILT\PDF',
          fullPath: r'C:\Docs\AS BUILT\PDF\DNSSGM12000JCSS70001-0001.pdf',
          code: 'DNSSGM12000JCSS700',
          documentTypeCode: 'JC',
          sizeInBytes: 4096,
        ),
        IndexedFile(
          fileName: 'T2404.pdf',
          directoryPath: r'C:\Docs\AS BUILT\T2404',
          fullPath: r'C:\Docs\AS BUILT\T2404\T2404.pdf',
          code: 'T2404',
          documentTypeCode: '',
          sizeInBytes: 1024,
        ),
      ],
    );
  }

  group('FileIndexerScreen widget tests', () {
    testWidgets('renders folder picker and empty state', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const FileIndexerScreen()));
      await tester.pumpAndSettle();

      expect(find.text('File Indexer & CSV Export'), findsOneWidget);
      expect(find.text('Folder to Index'), findsOneWidget);
      expect(find.text('Browse Folder'), findsOneWidget);
      expect(find.text('Index Folder'), findsOneWidget);
      expect(find.text('Include subfolders'), findsOneWidget);
      expect(find.text('Copy duplicate document codes'), findsOneWidget);
      expect(find.text('Duplicate Codes Destination'), findsNothing);
      expect(find.text('No folder indexed yet'), findsOneWidget);

      final exportButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Export CSV'),
      );
      expect(exportButton.onPressed, isNull);
    });

    testWidgets('indexes a folder and renders code and document type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: _FakeIndexService(buildSampleResult()),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      expect(find.text('Indexed Files'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('DNSSGM12000JCSS70001-0001.dwg'), findsOneWidget);
      expect(find.text('DNSSGM12000JCSS700'), findsOneWidget);
      expect(find.text('JC'), findsOneWidget);
      expect(find.text('T2404.pdf'), findsOneWidget);
      expect(find.text('T2404'), findsOneWidget);
      expect(find.text('.dwg'), findsOneWidget);
      expect(find.text('.pdf'), findsOneWidget);
      expect(find.text('Showing 1-2 of 2'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);

      final table = find.byType(DataTable);
      expect(
        find.descendant(of: table, matching: find.text('Index')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('2')),
        findsOneWidget,
      );

      // The table is centered horizontally inside its card.
      final tableCenter = tester.getCenter(table);
      expect(tableCenter.dx, closeTo(800, 40));
    });

    testWidgets('shows a progress indicator while the folder is indexing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _PendingIndexService();

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pump();

      expect(find.text('Indexing folder...'), findsOneWidget);
      expect(find.text('Indexing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('No folder indexed yet'), findsNothing);

      service.completer.complete(buildSampleResult());
      await tester.pumpAndSettle();

      expect(find.text('Indexing folder...'), findsNothing);
      expect(find.text('Indexed Files'), findsOneWidget);
    });

    testWidgets('paints the loading indicator before the scan starts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var loadingVisibleWhenScanStarted = false;
      final service = _CallbackIndexService(
        buildSampleResult(),
        onStart: () {
          loadingVisibleWhenScanStarted = find
              .text('Indexing folder...')
              .evaluate()
              .isNotEmpty;
        },
      );

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      expect(loadingVisibleWhenScanStarted, isTrue);
    });

    testWidgets('search narrows the table to matching files', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: _FakeIndexService(buildSampleResult()),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search name, code, type or folder',
      );

      await tester.enterText(searchField, 'T2404');
      await tester.pumpAndSettle();

      expect(find.text('T2404.pdf'), findsOneWidget);
      expect(find.text('DNSSGM12000JCSS70001-0001.dwg'), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);

      // Filtering keeps the original row index so it stays aligned with the
      // row number in the exported CSV.
      final table = find.byType(DataTable);
      expect(
        find.descendant(of: table, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('1')),
        findsNothing,
      );
    });

    testWidgets('duplicate copy controls appear only when the switch is on', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeCopyService(buildDuplicateResult());

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Codes Destination'), findsNothing);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Codes Destination'), findsOneWidget);

      final destinationField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Duplicate Codes Destination',
        ),
      );
      expect(
        destinationField.controller?.text,
        equals(r'C:\Docs\AS BUILT - Duplicate Codes'),
      );
      expect(find.text('Copy Duplicates (1)'), findsOneWidget);
      expect(
        find.textContaining('1 document code(s) shared by 2 files'),
        findsOneWidget,
      );
    });

    testWidgets('copies duplicate codes to the selected destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeCopyService(buildDuplicateResult());

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            // Point the rules at a non-existent file so the copy test does not
            // read the developer's real shared rules and stays hermetic.
            rulesService: AllowedTypesRulesService(
              filePath: p.join(Directory.systemTemp.path, 'ft_no_rules.json'),
            ),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      final destinationField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Duplicate Codes Destination',
      );

      await tester.enterText(destinationField, r'D:\Duplicate Codes');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Duplicates (1)'));
      await tester.pumpAndSettle();

      expect(service.copiedDestination, equals(r'D:\Duplicate Codes'));
      expect(
        find.textContaining('Duplicate copy: 2 file(s) into 1 code folder(s)'),
        findsOneWidget,
      );
      expect(find.text(r'D:\Duplicate Codes'), findsNWidgets(2));
    });

    testWidgets('moves disallowed files to trash after copying', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tempDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('ft_ui_trash_'),
      );
      addTearDown(() {
        if (tempDir != null && tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final rulesPath = p.join(tempDir!.path, 'allowed_types.json');
      await tester.runAsync(
        () => File(rulesPath).writeAsString('{"JC": ["pdf"]}'),
      );

      const trashResult = TrashResult(
        destinationRoot: r'D:\Duplicate Codes',
        trashRoot: r'D:\Duplicate Codes\trash',
        movedTo: {
          r'C:\Docs\AS BUILT\DWG\DNSSGM12000JCSS70001-0001.dwg':
              r'D:\Duplicate Codes\trash\DNSSGM12000JCSS700'
              r'\DNSSGM12000JCSS70001-0001.dwg',
        },
      );

      final service = _FakeCopyService(
        buildDuplicateResult(),
        trashResult: trashResult,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            rulesService: AllowedTypesRulesService(filePath: rulesPath),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      final destinationField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Duplicate Codes Destination',
      );

      await tester.enterText(destinationField, r'D:\Duplicate Codes');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Duplicates (1)'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Trash cleanup: 1 file(s) moved'),
        findsOneWidget,
      );
      expect(find.textContaining('Moved 1 to trash'), findsOneWidget);
    });

    testWidgets('flatten switch defaults on', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeCopyService(buildDuplicateResult());

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      final flattenSwitch = find.byKey(
        const Key('flatten-single-file-folders-switch'),
      );
      expect(flattenSwitch, findsOneWidget);
      expect(tester.widget<Switch>(flattenSwitch).value, isTrue);
      expect(find.text('Flatten single-file folders'), findsOneWidget);
    });

    testWidgets('flattens single-file folders after copying', (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const flattenResult = FlattenResult(
        destinationRoot: r'D:\Duplicate Codes',
        movedTo: {
          r'D:\Duplicate Codes\DNSSGM12000JCSS700\DNSSGM12000JCSS70001-0001.pdf':
              r'D:\Duplicate Codes\DNSSGM12000JCSS70001-0001.pdf',
        },
        removedFolders: [r'D:\Duplicate Codes\DNSSGM12000JCSS700'],
      );

      final service = _FakeCopyService(
        buildDuplicateResult(),
        flattenResult: flattenResult,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            rulesService: AllowedTypesRulesService(
              filePath: p.join(Directory.systemTemp.path, 'ft_no_rules.json'),
            ),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      final destinationField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Duplicate Codes Destination',
      );
      await tester.enterText(destinationField, r'D:\Duplicate Codes');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Duplicates (1)'));
      await tester.pumpAndSettle();

      expect(service.flattenedDestination, equals(r'D:\Duplicate Codes'));
      expect(find.textContaining('Flatten: 1 file(s) moved'), findsOneWidget);
      expect(find.textContaining('Flattened 1 folder(s).'), findsOneWidget);
    });

    testWidgets('skips flattening when the switch is off', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeCopyService(buildDuplicateResult());

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: service,
            rulesService: AllowedTypesRulesService(
              filePath: p.join(Directory.systemTemp.path, 'ft_no_rules.json'),
            ),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      // Turn the flatten switch off (the copy switch stays on).
      final flattenSwitch = find.byKey(
        const Key('flatten-single-file-folders-switch'),
      );
      expect(tester.widget<Switch>(flattenSwitch).value, isTrue);
      await tester.tap(flattenSwitch);
      await tester.pumpAndSettle();

      final destinationField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Duplicate Codes Destination',
      );
      await tester.enterText(destinationField, r'D:\Duplicate Codes');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Duplicates (1)'));
      await tester.pumpAndSettle();

      expect(service.flattenedDestination, isNull);
      expect(find.textContaining('Flatten:'), findsNothing);
    });

    testWidgets('edits shared document type file rules', (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tempDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('ft_ui_rules_'),
      );
      addTearDown(() {
        if (tempDir != null && tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final rulesPath = p.join(tempDir!.path, 'allowed_types.json');

      await tester.pumpWidget(
        buildTestableWidget(
          FileIndexerScreen(
            indexService: _FakeCopyService(buildDuplicateResult()),
            rulesService: AllowedTypesRulesService(filePath: rulesPath),
            initialFolderPath: r'C:\Docs\AS BUILT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Index Folder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('File Type Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Allowed File Types per Document Type'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '.dwg'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '.pdf'), findsOneWidget);

      final dwgChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '.dwg'),
      );
      expect(dwgChip.selected, isTrue);

      await tester.tap(find.widgetWithText(FilterChip, '.dwg'));
      await tester.pumpAndSettle();

      final saved = jsonDecode(File(rulesPath).readAsStringSync());
      expect(saved, isA<Map<String, dynamic>>());
      expect((saved as Map<String, dynamic>)['JC'], equals(['pdf']));

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('opens from the configuration screen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const ConfigurationScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open File Indexer'));
      await tester.pumpAndSettle();

      expect(find.text('File Indexer & CSV Export'), findsOneWidget);
      expect(find.text('Folder to Index'), findsOneWidget);
    });
  });
}
