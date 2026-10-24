# VS Code & Tooling Reference (`flutter-dev-setup`)

## Launch Options Configuration

In Flutter projects, `.vscode/launch.json` provides the primary interface for running and profiling across targets:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter: Debug (Windows)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main_dev.dart",
      "args": ["-d", "windows", "--dart-define-from-file=config/dev.json"]
    },
    {
      "name": "Flutter: Profile (Windows)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main_dev.dart",
      "flutterMode": "profile",
      "args": ["-d", "windows", "--dart-define-from-file=config/dev.json"]
    },
    {
      "name": "Flutter: Release (Windows)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main_prod.dart",
      "flutterMode": "release",
      "args": ["-d", "windows", "--dart-define-from-file=config/prod.json"]
    }
  ]
}
```

## VS Code Settings

Configure `.vscode/settings.json` to enforce consistent workspace formatting:

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit"
  },
  "dart.flutterAdditionalArgs": ["-d", "windows"]
}
```
