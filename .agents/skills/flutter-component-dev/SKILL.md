---
name: flutter-component-dev
description: >-
  Build production-ready Flutter widgets and screens with BLoC state wiring, desktop ergonomics, semantic theme tokens, ARB localization, and widget tests.
---

# Flutter Component & Widget Development (`flutter-component-dev`)

Specialized workflow for creating production-ready Flutter presentation widgets and screens adhering to clean architectural layering, BLoC state wiring, desktop ergonomics, zero-hardcoded strings, and test-driven verification.

---

## Architectural Rules & Standards

### 1. Presentation Purity
- No direct database, file system, or network calls inside `Widget.build()`.
- UI widgets bind to states via `BlocBuilder`, `BlocSelector`, or `BlocConsumer`.

### 2. Loading & Error Feedback
- **Desktop Target**: Use subtle progress bars (`LinearProgressIndicator`), progress rings (`fluent_ui` / `CircularProgressIndicator`), or button spinners. Avoid full-screen mobile shimmering skeletons unless handling large multi-card remote grids.
- **Error Recovery**: Every async widget must implement an error state with a clear message and a retry callback.

### 3. Desktop Ergonomics
- Add `MouseRegion(cursor: SystemMouseCursors.click)` for custom interactive areas.
- Support right-click contextual menus with `ContextMenuRegion`.
- Manage keyboard focus cleanly with `FocusNode` and keyboard shortcuts (`Shortcuts`/`Actions`).

### 4. Zero Hardcoded Strings & RTL Support
- All user-facing strings must come from `context.l10n.<key>` or `AppLocalizations.of(context)`.
- Use `EdgeInsetsDirectional` and `AlignmentDirectional` to support RTL/LTR automatically.

---

## Step-by-Step Execution Checklist

- [ ] **Step 1: State Contract Alignment**
  - Verify BLoC events and states exist (`lib/src/logic/<feature>/`).
  - Ensure states provide explicit variants: `Initial`, `Loading`, `Success`, and `Failure`.
- [ ] **Step 2: Scaffolding the Widget**
  - Author the widget in `lib/src/presentation/widgets/<widget_name>.dart`.
  - Use `Theme.of(context).colorScheme` or custom `ThemeExtension` tokens.
- [ ] **Step 3: Desktop Ergonomics Integration**
  - Add hover, keyboard, and focus handling if running on desktop targets.
- [ ] **Step 4: Widget Testing (TDD)**
  - Author `test/presentation/<widget_name>_test.dart`.
  - Test `Loading`, `Success`, and `Failure` state rendering.
  - Test user interaction (taps, inputs).
- [ ] **Step 5: Targeted Test Run**
  - Execute the test:
    ```powershell
    flutter test test/presentation/<widget_name>_test.dart
    ```

---

## Edge Cases & Known AI Pitfalls

- **Unmounted Context**: Never call `Navigator` or `ScaffoldMessenger` across async gaps without checking `if (!context.mounted) return;`.
- **Text Overflow**: Wrap long or dynamic text with `overflow: TextOverflow.ellipsis` or place inside scrollable containers.
- **Controller Leaks**: Always dispose `TextEditingController`, `ScrollController`, and `FocusNode` in `State.dispose()`.

---

## Reference Guides

- [Desktop Ergonomics Guide](./references/desktop-ergonomics.md)
- [Theming & Tokens Guide](./references/theme-and-tokens.md)
- [Localization & RTL Guide](./references/l10n-and-rtl.md)
