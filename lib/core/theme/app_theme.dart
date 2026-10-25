import 'package:flutter/material.dart';
import 'app_semantic_tokens.dart';

/// Centralized Material 3 Light and Dark Theme configurations.
abstract final class AppTheme {
  // Brand seed color for FtFileSorter
  static const Color seedColor = Color.fromARGB(255, 85, 241, 54);

  /// Material 3 Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppSemanticTokens.light.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: const [
        AppSemanticTokens.light,
      ],
    );
  }

  /// Material 3 Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppSemanticTokens.dark.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: const [
        AppSemanticTokens.dark,
      ],
    );
  }
}
