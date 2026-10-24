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

## Commit Lint & Conventional Commits (`commitlint_cli`)

To guarantee automated releases with `release-please`, commit messages must adhere to Conventional Commits format (`feat:`, `fix:`, `chore:`, etc.).

1. Add `commitlint_cli` as a development dependency:
   ```bash
   flutter pub add --dev commitlint_cli
   ```

2. Create `commitlint.yaml` at repository root:
   ```yaml
   include: package:commitlint_cli/commitlint.yaml

   rules:
     scope-enum:
       - 0
       - never
   ```

## Hook Configuration (`lefthook.yml`)

Configure `lefthook.yml` at the root with `commit-msg` linting enabled:

```yaml
pre-commit:
  parallel: false
  commands:
    formatting:
      run: dart format --set-exit-if-changed .
    analysis:
      run: flutter analyze --fatal-infos

commit-msg:
  parallel: false
  commands:
    lint-commit:
      run: dart run commitlint_cli --edit {1}

pre-push:
  parallel: false
  commands:
    tests:
      run: flutter test
```

## Git Hook Fallback (`.githooks/commit-msg`)

For environments without standalone Lefthook binary installed, configure a tracked Git hook:
1. Create `.githooks/commit-msg`:
   ```sh
   #!/bin/sh
   exec dart run commitlint_cli --edit "$1"
   ```
2. Activate tracked hooks in repository:
   ```bash
   git config core.hooksPath .githooks
   ```
