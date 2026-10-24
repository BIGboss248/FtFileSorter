# Desktop Ergonomics Guide (`flutter-component-dev`)

When building Flutter components for Windows or desktop targets, incorporate native desktop interaction patterns:

## 1. Mouse Cursors & Hover States

Wrap clickable custom widgets with `MouseRegion`:

```dart
MouseRegion(
  cursor: SystemMouseCursors.click,
  onEnter: (_) => setState(() => _isHovered = true),
  onExit: (_) => setState(() => _isHovered = false),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      color: _isHovered ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
    ),
    child: child,
  ),
)
```

## 2. Right-Click Context Menus

Support right-click interactions via `GestureDetector(onSecondaryTap: ...)` or platform context menu builders.

## 3. Keyboard Navigation

- Ensure text inputs and actionable lists can be navigated via the Tab key using `FocusNode`.
- Wire default actions to the Enter key (`onSubmitted`).
- Map Esc to close dialogs or cancel active selections.
