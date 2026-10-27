import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/app_theme.dart';
import 'package:ft_file_sorter/src/data/models/indexed_file.dart';
import 'package:ft_file_sorter/src/logic/services/file_index_service.dart';
import 'package:ft_file_sorter/src/presentation/screens/configuration_screen.dart';
import 'package:ft_file_sorter/src/presentation/screens/file_indexer_screen.dart';
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
