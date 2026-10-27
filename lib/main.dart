import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'src/presentation/screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  runApp(MyApp(savedThemeMode: savedThemeMode));
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  const MyApp({super.key, this.savedThemeMode});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: AppTheme.lightTheme,
      dark: AppTheme.darkTheme,
      initial: savedThemeMode ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: 'Ft File Sorter',
        theme: theme,
        darkTheme: darkTheme,
        home: const AppShell(),
      ),
    );
  }
}
