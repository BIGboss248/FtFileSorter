# Localization & RTL Guide (`flutter-component-dev`)

## ARB Conventions

All user-visible text must be defined in `lib/l10n/app_en.arb`:

```json
{
  "welcomeTitle": "Welcome back",
  "@welcomeTitle": {
    "description": "Greeting displayed on home dashboard"
  }
}
```

In widgets:
```dart
Text(context.l10n.welcomeTitle)
```

## Directional Layout Rules

- Use `EdgeInsetsDirectional.only(start: 16.0)` instead of `EdgeInsets.only(left: 16.0)`.
- Use `AlignmentDirectional.centerStart` instead of `Alignment.centerLeft`.
- This ensures automatic layout mirroring when switching between LTR (English) and RTL (Persian, Arabic).
