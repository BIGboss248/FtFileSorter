---
name: flutter-theme
description: Generates and integrates Material 3 light and dark themes with custom semantic ThemeExtensions, persistence repository, and an animated Sun-to-Moon toggle widget. Trigger with "flutter theme", "setup app theme", "create theme tokens", or "add theme toggle".
---

# Flutter Theming & Adaptive Theme Setup

Generates cohesive Material 3 Light/Dark themes from semantic design tokens, configures zero-boilerplate theme persistence via `adaptive_theme`, and provides a fluid Sun-to-Moon animated toggle button.

## Architecture & File Structure

```
lib/core/theme/
├── app_semantic_tokens.dart   # ThemeExtension for custom design tokens
├── app_theme.dart             # Light & Dark ThemeData configurations
├── theme_repository.dart      # Persistence contract and repository
└── widgets/
    └── animated_theme_toggle.dart # Sun <-> Moon morphing toggle button
```

## Step-by-Step Implementation Workflow

### 1. Add Dependencies
Add `adaptive_theme` to `pubspec.yaml`:
```bash
flutter pub add adaptive_theme
```

### 2. Compile Semantic Tokens
Extract semantic tokens from `docs/project.json` (or design specification) into a type-safe `ThemeExtension`:
- See [Semantic Tokens Guide](references/semantic-tokens.md) for architecture and `lerp` details.
- Scaffold from [app_semantic_tokens.dart.template](resources/templates/app_semantic_tokens.dart.template).
- Ensure each token defines distinct `light` and `dark` color values.

### 3. Build Light & Dark `ThemeData`
Construct centralized `ThemeData` instances in `app_theme.dart`:
- Set `useMaterial3: true`.
- Derive palettes using `ColorScheme.fromSeed` or explicit palette mappings.
- Register `AppSemanticTokens` inside the `extensions: [...]` list of both themes.
- Scaffold from [app_theme.dart.template](resources/templates/app_theme.dart.template).

### 4. Initialize Root Persistence in `main.dart`
Configure `AdaptiveTheme` at the application root to eliminate startup flicker:
- See [Adaptive Theme Guide](references/adaptive-theme.md) for full setup and caveats.
- Asynchronously read saved mode before `runApp()`:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    runApp(MyApp(savedThemeMode: savedThemeMode));
  }
  ```
- Wrap `MaterialApp` with `AdaptiveTheme`:
  ```dart
  AdaptiveTheme(
    light: AppTheme.lightTheme,
    dark: AppTheme.darkTheme,
    initial: savedThemeMode ?? AdaptiveThemeMode.system,
    builder: (theme, darkTheme) => MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      home: const HomeScreen(),
    ),
  );
  ```

### 5. Mount Animated Theme Toggle Button
Add the Sun-to-Moon animated toggle widget to the app bar or settings screen:
- See [Animated Toggle Guide](references/animated-toggle.md) for motion specs and curves.
- Scaffold from [animated_theme_toggle.dart.template](resources/templates/animated_theme_toggle.dart.template).
- Mount inside widget tree:
  ```dart
  AppBar(
    title: const Text('Dashboard'),
    actions: const [
      AnimatedThemeToggle(),
    ],
  )
  ```

## Verification Checklist

- [ ] Run `dart analyze` to ensure zero compilation or type errors.
- [ ] Verify light mode renders with expected light seed and semantic tokens.
- [ ] Tap the `AnimatedThemeToggle` button to verify smooth 450ms Sun-to-Moon rotation/scale transition.
- [ ] Confirm dark mode applies dark color scheme and dark semantic tokens.
- [ ] Restart the application and verify the selected theme mode persists across reboots.
