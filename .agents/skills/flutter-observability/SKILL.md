---
name: flutter-observability
description: >-
  Configure structured logging, global BLoC state tracing, HTTP network interceptors, and crash reporting boundaries across Flutter applications.
---

# Flutter Observability & Diagnostics (`flutter-observability`)

Production-grade runbook for implementing structured logging, global state machine observability, network tracing, and error boundary capture in Flutter desktop and mobile apps.

---

## Architectural Rules & Standards

### 1. Zero Direct Prints
- `print()` is strictly forbidden in production code (enforced by `analysis_options.yaml`).
- Use structured loggers (`logger` package or `dart:developer.log`) with log levels (`debug`, `info`, `warning`, `error`).

### 2. Global BLoC Observer
- Implement a custom `BlocObserver` attached to `Bloc.observer` in `main.dart` to trace all state transitions and errors.

### 3. Network Tracing & Correlation IDs
- Attach a logging interceptor to HTTP/Dio clients to record request duration, status codes, and errors while sanitizing authentication tokens.

### 4. Global Error Boundaries
- Capture framework errors via `FlutterError.onError`.
- Capture async isolate exceptions via `PlatformDispatcher.instance.onError`.

---

## Step-by-Step Execution Checklist

- [ ] **Step 1: Scaffold AppBlocObserver**
  - Create `lib/src/core/observability/app_bloc_observer.dart` using [app_bloc_observer.dart.template](./resources/templates/app_bloc_observer.dart.template).
  - Register in `main()` before `runApp()`.
- [ ] **Step 2: Structured Logger Setup**
  - Create `lib/src/core/observability/app_logger.dart` configuring output levels and file logging for desktop troubleshooting.
- [ ] **Step 3: Network Interceptor Integration**
  - Add request logging interceptor to the base `Dio` or HTTP client.
- [ ] **Step 4: Global Crash Handlers**
  - Bind `FlutterError.onError` and `PlatformDispatcher.instance.onError` in `main.dart`.

---

## Edge Cases & Known AI Pitfalls

- **PII Leakage**: Never log raw password, JWT auth tokens, or user personal data in plain text log files or console streams.
- **Log File Growth**: If writing log files to disk on desktop (`getApplicationSupportDirectory()`), implement log rotation (e.g., maximum 5MB with 3 backup files).
- **Infinite Error Loops**: In custom error handlers, avoid triggering operations that throw new errors to prevent cascading stack overflows.

---

## Reference Guides

- [Logging Standards & Desktop File Rotation](./references/logging-standards.md)
- [Error Boundaries & Crash Reporting](./references/error-boundaries.md)
- [AppBlocObserver Template](./resources/templates/app_bloc_observer.dart.template)
