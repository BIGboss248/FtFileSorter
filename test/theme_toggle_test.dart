import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/widgets/animated_theme_toggle.dart';
import 'package:ft_file_sorter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('AnimatedThemeToggle switches theme between light and dark',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(savedThemeMode: AdaptiveThemeMode.light));
    await tester.pumpAndSettle();

    // Verify AnimatedThemeToggle exists in AppBar
    expect(find.byType(AnimatedThemeToggle), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Tap toggle button to switch to dark mode
    await tester.tap(find.byType(AnimatedThemeToggle));
    await tester.pumpAndSettle();

    // Verify icon switched to dark mode moon
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    // Tap toggle button to switch back to light mode
    await tester.tap(find.byType(AnimatedThemeToggle));
    await tester.pumpAndSettle();

    // Verify icon switched back to light mode sun
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });
}
