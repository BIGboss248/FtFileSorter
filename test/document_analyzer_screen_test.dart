import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/app_theme.dart';
import 'package:ft_file_sorter/src/presentation/screens/configuration_screen.dart';
import 'package:ft_file_sorter/src/presentation/screens/document_analyzer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
      builder: (theme, darkTheme) => MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        home: child,
      ),
    );
  }

  group('DocumentAnalyzerScreen Widget Tests', () {
    testWidgets('renders both required inputs and empty analysis placeholder', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DocumentAnalyzerScreen()));
      await tester.pumpAndSettle();

      // Verify screen title
      expect(find.text('Document Code Analyzer (18-Char)'), findsOneWidget);

      // Verify Input 1: 18-character document code text field
      expect(find.text('1. 18-Character Document Code'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, ''), findsWidgets);

      // Verify Input 2: Save Target Directory field and browse button
      expect(find.text('2. Save Target Directory'), findsOneWidget);
      expect(find.text('Browse Directory'), findsOneWidget);

      // Verify empty state placeholder when no code is entered
      expect(find.text('Awaiting 18-Character Code'), findsOneWidget);
    });

    testWidgets('analyzes 18-character drawing code and updates analysis below in real time', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DocumentAnalyzerScreen()));
      await tester.pumpAndSettle();

      // Enter 18-character Drawing code: PRJ1020300DW000101
      final codeInput = find.byType(TextFormField).first;
      await tester.enterText(codeInput, 'PRJ1020300DW000101');
      await tester.pumpAndSettle();

      // Verify character counter shows 18 / 18
      expect(find.text('18 / 18 characters'), findsOneWidget);

      // Verify Document Type extracted from Chars 11 & 12 ('DW')
      expect(find.textContaining('Engineering Drawing'), findsWidgets);
      expect(find.text('DW'), findsWidgets);

      // Verify target file types to save for drawing
      expect(find.text('.pdf'), findsWidgets);
      expect(find.text('.dwg'), findsWidgets);
      expect(find.text('.dxf'), findsWidgets);

      // Verify Visual Segmentation Ribbon
      expect(find.text('PRJ1020300'), findsWidgets);
      expect(find.text('000101'), findsWidgets);

      // Verify valid status banner
      expect(find.textContaining('Valid 18-character code'), findsOneWidget);
    });

    testWidgets('clicking sample chip loads code and displays analysis immediately', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DocumentAnalyzerScreen()));
      await tester.pumpAndSettle();

      // Tap the Specification (SP) sample action chip
      final specChip = find.widgetWithText(ActionChip, 'Specification (SP)');
      expect(specChip, findsOneWidget);
      await tester.tap(specChip);
      await tester.pumpAndSettle();

      // Verify Document Type is Technical Specification and target files contain .docx
      expect(find.textContaining('Technical Specification'), findsWidgets);
      expect(find.text('SP'), findsWidgets);
      expect(find.text('.docx'), findsWidgets);
      expect(find.text('.doc'), findsWidgets);
    });

    testWidgets('navigates from ConfigurationScreen to DocumentAnalyzerScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const ConfigurationScreen()));
      await tester.pumpAndSettle();

      // Find and tap the navigation button in AppBar
      final navButton = find.text('Document Code Analyzer');
      expect(navButton, findsOneWidget);
      await tester.tap(navButton);
      await tester.pumpAndSettle();

      // Verify we are now on DocumentAnalyzerScreen
      expect(find.text('Document Code Analyzer (18-Char)'), findsOneWidget);
      expect(find.text('1. 18-Character Document Code'), findsOneWidget);
      expect(find.text('Browse Directory'), findsOneWidget);
    });
  });
}
