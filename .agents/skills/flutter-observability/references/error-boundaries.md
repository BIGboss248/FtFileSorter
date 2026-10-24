# Error Boundaries & Crash Reporting (`flutter-observability`)

## Setting Up Global Boundaries in `main.dart`

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Flutter framework layout/rendering errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter Framework Error: ${details.exceptionAsString()}', details.exception, details.stack);
  };

  // 2. Uncaught async Dart errors outside Flutter's build tree
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Platform Async Error: $error', error, stack);
    return true; // handled
  };

  runApp(const MyApp());
}
```
