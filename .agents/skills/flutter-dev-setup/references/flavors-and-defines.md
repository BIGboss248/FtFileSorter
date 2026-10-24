# Flavors & Environment Configuration (`flutter-dev-setup`)

Flutter supports multiple configuration strategies. The recommended approach uses `--dart-define-from-file` to keep environments strongly-typed and decoupled from source code.

## Configuration Files

### `config/dev.json`
```json
{
  "APP_ENV": "development",
  "API_BASE_URL": "http://127.0.0.1:8080/api/v1",
  "ENABLE_LOGGING": true,
  "SHOW_DEBUG_BANNER": true
}
```

### `config/prod.json`
```json
{
  "APP_ENV": "production",
  "API_BASE_URL": "https://api.myproductiondomain.com/api/v1",
  "ENABLE_LOGGING": false,
  "SHOW_DEBUG_BANNER": false
}
```

## Consuming Environment in Dart

Create an `AppConfig` class in `lib/src/core/config/app_config.dart`:

```dart
class AppConfig {
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8080/api/v1');
  static const enableLogging = bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);
  static const showDebugBanner = bool.fromEnvironment('SHOW_DEBUG_BANNER', defaultValue: true);

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
}
```

## Running Flavors

- Development:
  ```powershell
  flutter run -d windows -t lib/main_dev.dart --dart-define-from-file=config/dev.json
  ```
- Production:
  ```powershell
  flutter run -d windows -t lib/main_prod.dart --dart-define-from-file=config/prod.json
  ```
