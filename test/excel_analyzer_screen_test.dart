import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/app_theme.dart';
import 'package:ft_file_sorter/src/presentation/screens/excel_analyzer_screen.dart';
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

  testWidgets('ExcelAnalyzerScreen renders initial file input and browse button', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestableWidget(const ExcelAnalyzerScreen()));
    await tester.pumpAndSettle();

    // Initial app bar and instructions
    expect(find.text('Excel Metadata & Document Code Analysis'), findsOneWidget);
    expect(find.text('Excel Data Source'), findsOneWidget);
    expect(find.text('Browse File'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
