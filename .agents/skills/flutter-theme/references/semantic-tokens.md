# Semantic Tokens & ThemeExtension Guide

## Overview

Semantic tokens bridge abstract design tokens (e.g., `cardBorder`, `accentSubtle`, `statusSuccess`) from `docs/project.json` into type-safe Flutter widgets without polluting standard `ColorScheme` properties.

## Token Extraction Workflow

1. Inspect `docs/project.json` under `theming.semantic_tokens` and `theming.color_palettes`.
2. Map each token to:
   - A Dart `Color` property inside an `AppSemanticTokens` class extending `ThemeExtension<AppSemanticTokens>`.
   - Distinct hex values for Light and Dark modes.
3. Implement `copyWith` and `lerp` for smooth transitions between themes during animation.

## Type-Safe Extension Boilerplate

```dart
import 'package:flutter/material.dart';

@immutable
class AppSemanticTokens extends ThemeExtension<AppSemanticTokens> {
  final Color cardBorder;
  final Color accentSubtle;
  final Color statusSuccess;

  const AppSemanticTokens({
    required this.cardBorder,
    required this.accentSubtle,
    required this.statusSuccess,
  });

  @override
  AppSemanticTokens copyWith({
    Color? cardBorder,
    Color? accentSubtle,
    Color? statusSuccess,
  }) {
    return AppSemanticTokens(
      cardBorder: cardBorder ?? this.cardBorder,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      statusSuccess: statusSuccess ?? this.statusSuccess,
    );
  }

  @override
  AppSemanticTokens lerp(ThemeExtension<AppSemanticTokens>? other, double t) {
    if (other is! AppSemanticTokens) return this;
    return AppSemanticTokens(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
    );
  }
}
```

## Context Shortcut Extension

To prevent boilerplate lookups (`Theme.of(context).extension<AppSemanticTokens>()!`), provide a BuildContext extension:

```dart
extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(context);
  ColorScheme get colorScheme => theme.colorScheme;
  AppSemanticTokens get semanticTokens =>
      theme.extension<AppSemanticTokens>() ?? AppSemanticTokens.fallback;
}
```
