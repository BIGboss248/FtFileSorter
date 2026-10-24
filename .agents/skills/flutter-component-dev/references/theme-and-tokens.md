# Theming & Tokens Guide (`flutter-component-dev`)

## Semantic ColorScheme Usage

Always bind widget styles to `Theme.of(context).colorScheme`:
- Surface & Background: `colorScheme.surface`, `colorScheme.onSurface`
- Interactive Primary: `colorScheme.primary`, `colorScheme.onPrimary`
- Secondary Container: `colorScheme.secondaryContainer`

## Custom Brand Tokens via ThemeExtension

For custom brand colors not in `ColorScheme`:

```dart
class AppCustomTokens extends ThemeExtension<AppCustomTokens> {
  final Color accentGlow;
  final Color statusWarning;

  const AppCustomTokens({required this.accentGlow, required this.statusWarning});

  @override
  ThemeExtension<AppCustomTokens> copyWith() => this;

  @override
  ThemeExtension<AppCustomTokens> lerp(ThemeExtension<AppCustomTokens>? other, double t) => this;
}
```
