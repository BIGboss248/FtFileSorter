import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/core/theme/app_constants.dart';
import 'package:ft_file_sorter/core/theme/app_semantic_tokens.dart';
import 'package:ft_file_sorter/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses the generated Material 3 color scheme', () {
      final theme = AppTheme.lightTheme;

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFFC1161B));
      expect(theme.colorScheme.surface, const Color(0xFFFFFBFE));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(theme.useMaterial3, isTrue);
    });

    test('dark theme uses the generated Material 3 color scheme', () {
      final theme = AppTheme.darkTheme;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, const Color(0xFFad0207));
      expect(theme.colorScheme.surface, const Color(0xFF10090D));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('typography follows the AppConstants scale', () {
      final textTheme = AppTheme.lightTheme.textTheme;

      expect(
        textTheme.displayLarge?.fontSize,
        AppConstants.fontSizeDisplayLarge,
      );
      expect(textTheme.bodyMedium?.fontSize, AppConstants.fontSizeBodyMedium);
      expect(textTheme.titleMedium?.fontSize, AppConstants.fontSizeTitleMedium);
    });

    test('semantic tokens are registered for both brightnesses', () {
      final lightTokens = AppTheme.lightTheme.extension<AppSemanticTokens>();
      final darkTokens = AppTheme.darkTheme.extension<AppSemanticTokens>();

      expect(lightTokens, isNotNull);
      expect(darkTokens, isNotNull);
      expect(
        lightTokens?.cardBorder,
        AppTheme.lightTheme.colorScheme.outlineVariant,
      );
      expect(
        darkTokens?.cardBorder,
        AppTheme.darkTheme.colorScheme.outlineVariant,
      );
    });

    test('contrast variants build with the expected brightness', () {
      expect(AppTheme.lightMediumContrast.brightness, Brightness.light);
      expect(AppTheme.lightHighContrast.brightness, Brightness.light);
      expect(AppTheme.darkMediumContrast.brightness, Brightness.dark);
      expect(AppTheme.darkHighContrast.brightness, Brightness.dark);
    });
  });
}
