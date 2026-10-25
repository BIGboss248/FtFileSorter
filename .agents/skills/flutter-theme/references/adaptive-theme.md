# Adaptive Theme Integration Guide

This guide covers integrating the [`adaptive_theme`](https://pub.dev/packages/adaptive_theme) package (`v3.8.0`+) with Material 3, persistence, and state listeners.

## Key Package Capabilities

- **Zero-Boilerplate Persistence**: Persists `AdaptiveThemeMode` (light, dark, system) across app restarts via `shared_preferences`.
- **Flicker-Free Startup**: Asynchronously resolves saved theme mode before `runApp()` with `AdaptiveTheme.getThemeMode()`.
- **Reactive Notification**: `AdaptiveTheme.of(context).modeChangeNotifier` emits changes as a `ValueNotifier<AdaptiveThemeMode>`.
- **Quick Toggling**: `AdaptiveTheme.of(context).toggleThemeMode()`.

## Setup & Root Initialization

### 1. Dependency
```yaml
dependencies:
  adaptive_theme: ^3.8.5
```

### 2. Main Entry Point (`lib/main.dart`)
```dart
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

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
        title: 'App',
        theme: theme,
        darkTheme: darkTheme,
        home: const Scaffold(),
      ),
    );
  }
}
```

## Theme Mode Controller Operations

Within any descendant widget:

```dart
// Check current mode
final currentMode = AdaptiveTheme.of(context).mode;
final isDark = AdaptiveTheme.of(context).brightness == Brightness.dark;

// Toggle between light & dark
AdaptiveTheme.of(context).toggleThemeMode();

// Explicit targets
AdaptiveTheme.of(context).setLight();
AdaptiveTheme.of(context).setDark();
AdaptiveTheme.of(context).setSystem();
```

## Caveats & SharedPreferences Clearing

`adaptive_theme` persists state in `shared_preferences` under the key:
```dart
AdaptiveTheme.prefKey
```
When clearing user sessions on logout, exclude `AdaptiveTheme.prefKey`, or immediately re-persist:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
AdaptiveTheme.persist();
```
