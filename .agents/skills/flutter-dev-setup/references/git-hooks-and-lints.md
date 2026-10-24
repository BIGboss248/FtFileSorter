# Git Hooks & Static Analysis (`flutter-dev-setup`)

## Static Analysis Options

In `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    unawaited_futures: true
    always_declare_return_types: true
    cancel_subscriptions: true
    close_sinks: true
```

## Lefthook Configuration

Install `lefthook` (executable binary or via pub) and add `lefthook.yml` at the root:

```yaml
pre-commit:
  parallel: false
  commands:
    formatting:
      run: dart format --set-exit-if-changed .
    analysis:
      run: flutter analyze --fatal-infos

pre-push:
  parallel: false
  commands:
    tests:
      run: flutter test
```
