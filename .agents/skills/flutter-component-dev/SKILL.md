---
name: flutter-component-dev
description: >-
  Build production-ready Flutter widgets and screens with embedded diagnostic logging (dart:developer levels), theme tokens, ARB localization, and desktop ergonomics. Trigger with "flutter component dev", "create widget", "build screen", or "add flutter component".
---

# Flutter Component & Widget Development (`flutter-component-dev`)

Specialized workflow for creating production-ready Flutter presentation widgets and screens driven by [`docs/project.json`](file:///d:/Scripts/FtFileSorter/docs/project.json)—adhering to clean architectural layering, configured state management, semantic theme tokens, desktop ergonomics, embedded diagnostic logging (`dart:developer`), zero-hardcoded strings, and test-driven verification.

---

## Architectural Rules & Standards (Driven by `docs/project.json`)

### 1. Specification Inspection
Before authoring any widget or screen, read `docs/project.json`:
- **State Management**: Identify `project.json.state_management.library` (`bloc`, `cubit`, `riverpod`, etc.) to use the appropriate state consumer/builder.
- **Theming & Color Palettes**: Identify `project.json.theming.color_palettes` and `project.json.theming.semantic_tokens` to bind UI elements to `Theme.of(context).colorScheme` or `Theme.of(context).extension<AppThemeExtension>()`.
- **Localization**: Read `project.json.i18n.supported_locales` and `project.json.i18n.rtl_supported`.
- **Target Platforms**: Check `project.json.platforms` for desktop targets (`windows`, `macos`, `linux`).

### 2. Presentation Purity & State Wiring
- No direct database, file system, or network calls inside `Widget.build()`.
- Bind UI to state using the project's configured state management library:
  - **BLoC / Cubit**: Use `BlocBuilder`, `BlocSelector`, or `BlocConsumer`.
  - **Riverpod**: Extend `ConsumerWidget` or `ConsumerStatefulWidget` and bind via `ref.watch()`.

### 3. Loading, Feedback & Error Recovery
- **Desktop Target**: Use subtle progress bars (`LinearProgressIndicator`), progress rings (`CircularProgressIndicator`), or button spinners. Avoid full-screen mobile shimmering skeletons unless handling large remote grids.
- **Error Recovery**: Every async widget must implement an error state with a clear message and a retry callback.

### 4. Desktop Ergonomics (when desktop in `platforms`)
- Add `MouseRegion(cursor: SystemMouseCursors.click)` for interactive custom items.
- Support right-click contextual menus with `ContextMenuRegion`.
- Manage keyboard focus cleanly with `FocusNode` and keyboard shortcuts (`Shortcuts`/`Actions`).

### 5. Zero Hardcoded Strings & RTL Support
- Extract all user-facing strings into ARB catalogs across all `project.json.i18n.supported_locales` (e.g. `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`).
- Access strings via `AppLocalizations.of(context)!`.
- If `project.json.i18n.rtl_supported` is true, use `EdgeInsetsDirectional` and `AlignmentDirectional` exclusively.

### 6. Embedded Component Diagnostics & Logging (`dart:developer.log`)
- Embed structured logging in widgets using [`dart:developer.log`](https://api.flutter.dev/flutter/dart-developer/log.html) to make debugging fast and filterable in Flutter DevTools and IDE consoles.
- Standardize the logger tag with `name: '$runtimeType'` (or widget name) for instant log stream filtering.
- Apply standardized integer severity levels:
  - **DEBUG** (`level: 500`): State updates, rebuild diagnostics, controller listeners, animation ticks.
  - **INFO** (`level: 800`): `initState`, `dispose`, user interactions (taps, inputs, button presses, navigation).
  - **WARN** (`level: 900`): Non-fatal fallbacks (missing image/avatar, placeholder fallbacks), empty datasets, slow render alerts.
  - **ERROR** (`level: 1000`): Caught exceptions in callbacks, failed async tasks, network/image load failures (passing `error` and `stackTrace`).
  - **FATAL** (`level: 1200`): Critical UI invariant breaches, unhandled exhaustive enum/state branches, unrecoverable assertion breaks.
- See [Component Logging & Diagnostics Guide](./references/component-logging.md).

---

## Step-by-Step Execution Checklist

- [ ] **Step 1: Inspect `docs/project.json`**
  - Verify state library, theme tokens, supported locales, and target platforms.
- [ ] **Step 2: State Contract Alignment**
  - Verify state events, notifications, and status variants (`Initial`, `Loading`, `Success`, `Failure`).
- [ ] **Step 3: Scaffolding the Widget**
  - Author the widget in `lib/src/presentation/widgets/<widget_name>.dart`.
  - Use `Theme.of(context).colorScheme` or custom `ThemeExtension` tokens.
- [ ] **Step 4: Desktop Ergonomics Integration**
  - Add hover, keyboard, and focus handling if running on desktop targets.
- [ ] **Step 5: Diagnostic Logging Integration**
  - Embed `dart:developer.log()` across lifecycle (`initState`/`dispose`), user action triggers, fallback branches (`WARN`), and error states (`ERROR` / `FATAL`).
- [ ] **Step 6: Widget Testing (TDD)**
  - Author `test/presentation/<widget_name>_test.dart`.
  - Test `Loading`, `Success`, and `Failure` state rendering.
  - Test user interaction (taps, inputs).
- [ ] **Step 7: Targeted Test Run**
  - Execute the test:
    ```powershell
    flutter test test/presentation/<widget_name>_test.dart
    ```

---

## Edge Cases & Known AI Pitfalls

- **Unmounted Context**: Never call `Navigator` or `ScaffoldMessenger` across async gaps without checking `if (!context.mounted) return;`.
- **Text Overflow**: Wrap long or dynamic text with `overflow: TextOverflow.ellipsis` or place inside scrollable containers.
- **Controller Leaks**: Always dispose `TextEditingController`, `ScrollController`, and `FocusNode` in `State.dispose()`.
- **DevTools Log Spam**: Never invoke logging unconditionally inside repetitive hot loops or raw `build()` without state change guards.

---

## Reference Guides

- [Component Logging & Diagnostics Guide](./references/component-logging.md)
- [Desktop Ergonomics Guide](./references/desktop-ergonomics.md)
- [Theming & Tokens Guide](./references/theme-and-tokens.md)
- [Localization & RTL Guide](./references/l10n-and-rtl.md)
