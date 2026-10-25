# Component Logging & Diagnostics Guide (`flutter-component-dev`)

This guide specifies how to embed structured diagnostic logging in Flutter widgets using [`dart:developer.log`](https://api.flutter.dev/flutter/dart-developer/log.html).

---

## 1. Why `dart:developer.log`?

- **Zero External Dependencies**: Built directly into the Dart SDK (`dart:developer`).
- **Flutter DevTools Integration**: Logs stream directly into the Flutter DevTools **Logging** view, searchable by `name` and filterable by `level`.
- **IDE Debug Consoles**: Integrated with VS Code Dart extension and Android Studio log streams with syntax highlighting and stack trace resolution.
- **Structured Parameters**: Supports `name`, `level`, `error`, `stackTrace`, and `time` natively.

---

## 2. Standard Severity Levels

`dart:developer.log` uses integer severity levels (compatible with `package:logging` and DevTools filters):

| Level | Value | Purpose | When to Use in Widgets |
| :--- | :---: | :--- | :--- |
| **DEBUG** | `500` | Detailed diagnostic events | Controller updates, rebuild diagnostics, animation tick events, focus shifts |
| **INFO** | `800` | Major lifecycle & interactions | `initState`, `dispose`, user button taps, tab navigation, form submissions |
| **WARN** | `900` | Non-fatal irregularities | Fallback rendering (missing avatar/image), empty data sets, retries, slow operations |
| **ERROR** | `1000` | Handled failures & exceptions | Async action rejections, image load failures, form validation failures with stack trace |
| **FATAL** | `1200` | Critical invariant breaches | Unhandled state variants in switch expressions, broken UI assertions, corrupted models |

---

## 3. Standard Component Logging Helper

To avoid repetitive integer literals, widgets can define or reference a standardized helper:

```dart
import 'dart:developer' as developer;

abstract final class ComponentLogLevel {
  static const int debug = 500;
  static const int info = 800;
  static const int warning = 900;
  static const int error = 1000;
  static const int fatal = 1200;
}

/// Helper extension for convenient widget logging
extension WidgetLoggingX on Object {
  void logDebug(String message) => developer.log(
        message,
        name: '$runtimeType',
        level: ComponentLogLevel.debug,
      );

  void logInfo(String message) => developer.log(
        message,
        name: '$runtimeType',
        level: ComponentLogLevel.info,
      );

  void logWarn(String message, [Object? error]) => developer.log(
        message,
        name: '$runtimeType',
        level: ComponentLogLevel.warning,
        error: error,
      );

  void logError(String message, [Object? error, StackTrace? stackTrace]) => developer.log(
        message,
        name: '$runtimeType',
        level: ComponentLogLevel.error,
        error: error,
        stackTrace: stackTrace,
      );

  void logFatal(String message, [Object? error, StackTrace? stackTrace]) => developer.log(
        message,
        name: '$runtimeType',
        level: ComponentLogLevel.fatal,
        error: error,
        stackTrace: stackTrace,
      );
}
```

---

## 4. Widget Implementation Examples

### A. StatefulWidget Lifecycle & Interactions

```dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

class UserProfileCard extends StatefulWidget {
  final String userId;
  final VoidCallback onRefresh;

  const UserProfileCard({
    super.key,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  @override
  void initState() {
    super.initState();
    developer.log(
      'initState for user: ${widget.userId}',
      name: 'UserProfileCard',
      level: 800, // INFO
    );
  }

  @override
  void didUpdateWidget(covariant UserProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      developer.log(
        'userId changed from ${oldWidget.userId} to ${widget.userId}',
        name: 'UserProfileCard',
        level: 500, // DEBUG
      );
    }
  }

  @override
  void dispose() {
    developer.log(
      'dispose called for user: ${widget.userId}',
      name: 'UserProfileCard',
      level: 800, // INFO
    );
    super.dispose();
  }

  void _handleAction() {
    developer.log(
      'User tapped action button for user: ${widget.userId}',
      name: 'UserProfileCard',
      level: 800, // INFO
    );
    try {
      widget.onRefresh();
    } catch (e, st) {
      developer.log(
        'Failed to execute onRefresh',
        name: 'UserProfileCard',
        level: 1000, // ERROR
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('User: ${widget.userId}'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _handleAction,
        ),
      ),
    );
  }
}
```

### B. State Handling & Fallback Warnings in BLoC / Consumer

```dart
Widget buildState(BuildContext context, ProfileState state) {
  return switch (state) {
    ProfileInitial() => const SizedBox.shrink(),
    ProfileLoading() => const CircularProgressIndicator(),
    ProfileLoaded(:final user) => user.avatarUrl == null
        ? () {
            developer.log(
              'User avatar is null, using placeholder initials fallback',
              name: 'ProfileAvatar',
              level: 900, // WARN
            );
            return InitialsAvatar(name: user.name);
          }()
        : NetworkAvatar(url: user.avatarUrl!),
    ProfileFailure(:final error, :final stackTrace) => () {
        developer.log(
          'Rendering failure state view: $error',
          name: 'ProfileView',
          level: 1000, // ERROR
          error: error,
          stackTrace: stackTrace,
        );
        return ErrorStateView(error: error);
      }(),
  };
}
```

---

## 5. DevTools & Debugging Best Practices

1. **Tag with Widget Name**: Always specify `name: '$runtimeType'` or `'WidgetName'` so logs can be filtered in Flutter DevTools Logging View search box (`tag:WidgetName`).
2. **Attach Error and StackTrace**: In catch blocks or failure states, always pass `error: error` and `stackTrace: stackTrace` to enable one-click navigation in DevTools.
3. **Avoid Frame-Rate Spam**: Never log in the root `build()` method on every frame without a conditional throttle or guard (e.g., only log state transitions or first builds).
4. **Scrub PII**: Never log passwords, tokens, or private user credentials.
