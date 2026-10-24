# Release Please & CI/CD Guide (`flutter-dev-setup`)

## Release Please Manifests

### `release-please-config.json`
```json
{
  "packages": {
    ".": {
      "release-type": "dart",
      "package-name": "app",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true
    }
  }
}
```

### `.release-please-manifest.json`
```json
{
  ".": "1.0.0"
}
```

## GitHub Actions Release Pipeline

Deploy `.github/workflows/release-please.yml`:
- Set `concurrency: cancel-in-progress: false` on the release job.
- When Release Please merges a release PR:
  1. Check out code and set up Flutter.
  2. Run `flutter build windows --release --obfuscate --split-debug-info=build/symbols`.
  3. Archive the output directory `build/windows/x64/runner/Release/` to a `.zip` or MSIX file.
  4. Attach the binary and symbols to the generated GitHub Release tag.
