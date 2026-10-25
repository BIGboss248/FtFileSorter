import 'package:flutter/material.dart';

/// Semantic design tokens for FtFileSorter.
@immutable
class AppSemanticTokens extends ThemeExtension<AppSemanticTokens> {
  final Color cardBorder;
  final Color accentSubtle;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusError;

  const AppSemanticTokens({
    required this.cardBorder,
    required this.accentSubtle,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusError,
  });

  /// Light theme tokens
  static const light = AppSemanticTokens(
    cardBorder: Color(0xFFE2E8F0),
    accentSubtle: Color(0xFFEFF6FF),
    statusSuccess: Color(0xFF16A34A),
    statusWarning: Color(0xFFD97706),
    statusError: Color(0xFFDC2626),
  );

  /// Dark theme tokens
  static const dark = AppSemanticTokens(
    cardBorder: Color(0xFF334155),
    accentSubtle: Color(0xFF1E293B),
    statusSuccess: Color(0xFF22C55E),
    statusWarning: Color(0xFFF59E0B),
    statusError: Color(0xFFEF4444),
  );

  @override
  AppSemanticTokens copyWith({
    Color? cardBorder,
    Color? accentSubtle,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusError,
  }) {
    return AppSemanticTokens(
      cardBorder: cardBorder ?? this.cardBorder,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusError: statusError ?? this.statusError,
    );
  }

  @override
  AppSemanticTokens lerp(ThemeExtension<AppSemanticTokens>? other, double t) {
    if (other is! AppSemanticTokens) return this;
    return AppSemanticTokens(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
    );
  }
}

/// Helper extension on BuildContext to access semantic tokens easily.
extension SemanticTokensContext on BuildContext {
  AppSemanticTokens get semanticTokens =>
      Theme.of(this).extension<AppSemanticTokens>() ?? AppSemanticTokens.light;
}
