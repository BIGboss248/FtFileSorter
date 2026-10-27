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

  /// Light theme tokens (aligned with AppTheme.lightScheme)
  static const light = AppSemanticTokens(
    cardBorder: Color(0xFFCAC4D0),
    accentSubtle: Color(0xFFF7F2FA),
    statusSuccess: Color(0xFF2E7D32),
    statusWarning: Color(0xFFF57C00),
    statusError: Color(0xFFBA1A1A),
  );

  /// Dark theme tokens (aligned with AppTheme.darkScheme)
  static const dark = AppSemanticTokens(
    cardBorder: Color(0xFF49454F),
    accentSubtle: Color(0xFF1D1418),
    statusSuccess: Color(0xFF66BB6A),
    statusWarning: Color(0xFFFFB74D),
    statusError: Color(0xFFFFB4AB),
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
