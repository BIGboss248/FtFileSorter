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
  ".": "0.1.0"
}
```

## Windows MSIX Configuration (`pubspec.yaml`)

Add `msix` to `dev_dependencies` (`flutter pub add --dev msix`) and configure `msix_config:` at the root of `pubspec.yaml`:

```yaml
msix_config:
  display_name: AppName
  publisher_display_name: Author Name
  identity_name: com.example.appname
  publisher: CN=AuthorName
  msix_version: 1.0.0.0
  logo_path: windows/runner/resources/app_icon.ico
  capabilities: internetClient
  install_certificate: false
```

> [!CAUTION]
> **Critical `msix` Configuration Gotchas**:
> 1. **`capabilities` Must Be a Comma-Separated String**: Never format `capabilities` as a YAML list (`- internetClient`). `package:msix` parses `yaml['capabilities']` directly into a `String?` field (`Configuration.getConfigValues`), throwing `type 'YamlList' is not a subtype of type 'String?'` at runtime if a YAML list is used. Use `capabilities: internetClient, location`.
> 2. **Disable Certificate Prompt in CI (`install_certificate: false`)**: When signing with the default test certificate on headless CI runners, `msix:create` prompts interactively via stdin (`Do you want to install the certificate... (y/N)`). Always set `install_certificate: false` in `pubspec.yaml` and pass `--install-certificate false` in CI.
> 3. **Output Filename Matches `pubspec.yaml` `name`**: Unless `output_name` is explicitly set in `msix_config`, the generated installer is named `<pubspec_name>.msix` (e.g., `build\windows\x64\runner\Release\ft_file_sorter.msix`). Use `gh release upload <tag> path\to\<pubspec_name>.msix#<DisplayName>-windows.msix` to rename it cleanly on the GitHub Release page.

## Android Gradle & AGP Compatibility (`android/`)

When building on GitHub Actions (`subosito/flutter-action@v2` with `channel: stable`), the runner pulls the latest stable Flutter SDK, which enforces strict minimum Gradle and Kotlin Gradle Plugin (KGP) versions:

1. **Gradle Wrapper (`android/gradle/wrapper/gradle-wrapper.properties`)**:
   Ensure `distributionUrl` is at least **Gradle 9.1.0**:
   ```properties
   distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip
   ```
2. **Kotlin & AGP Versions (`android/settings.gradle.kts`)**:
   Latest Flutter stable requires **AGP 8.11.1+** (`com.android.application`) and **Kotlin 2.2.0+** (`org.jetbrains.kotlin.android`):
   ```kotlin
   plugins {
       id("dev.flutter.flutter-plugin-loader") version "1.0.0"
       id("com.android.application") version "8.11.1" apply false
       id("org.jetbrains.kotlin.android") version "2.2.0" apply false
   }
   ```
3. **AGP 9+ New DSL Opt-Out (`android/gradle.properties`)**:
   Include `android.newDsl=false` in `android/gradle.properties` to prevent AGP 9+ new DSL enforcement failures with the Flutter Gradle plugin:
   ```properties
   android.useAndroidX=true
   android.enableJetifier=true
   android.newDsl=false
   ```

## GitHub Actions Release Pipeline (Windows & Android)

Deploy [`.github/workflows/release-please.yml`](../resources/templates/release-please.yml.template):
- Set `concurrency: cancel-in-progress: false` on the workflow.
- **Job 1 (`release-please`)**: Runs `googleapis/release-please-action@v4` and exports `releases_created`, `tag_name`, and `version`.
- **Job 2 (`build-windows`)**: Runs on `windows-latest` when `releases_created == 'true'`:
  1. Checks out code and sets up Flutter (`subosito/flutter-action@v2`).
  2. Compiles obfuscated Windows release executable:
     `flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols`
  3. Packages Windows MSIX installer without rebuilding or prompting for certificate installation:
     `dart run msix:create --version ${{ needs.release-please.outputs.version }}.0 --build-windows false --install-certificate false`
  4. Compresses the portable release bundle (`build\windows\x64\runner\Release\*`) into `<App>-windows.zip`.
  5. Uploads both the `.msix` installer and `.zip` portable archive to the GitHub Release page via `gh release upload --clobber`.
- **Job 3 (`build-android`)**: Runs on `ubuntu-latest` when `releases_created == 'true'`:
  1. Checks out code, sets up Java 17 (`actions/setup-java@v5`), and sets up Flutter.
  2. Builds obfuscated Android APK (`flutter build apk --release --obfuscate --split-debug-info=build/android/symbols`).
  3. Builds obfuscated Android App Bundle (`flutter build appbundle --release --obfuscate --split-debug-info=build/android/symbols`).
  4. Uploads both `app-release.apk` (as `<App>-android.apk`) and `app-release.aab` (as `<App>-android.aab`) to the GitHub Release page via `gh release upload --clobber`.

## Repository Settings Requirement

> [!IMPORTANT]
> **GitHub Workflow Permissions for Release PRs**:
> Even with `permissions: pull-requests: write` in `.github/workflows/release-please.yml`, GitHub repositories by default prevent `GITHUB_TOKEN` from creating pull requests.
> If disabled, Release Please will fail at step `Run googleapis/release-please-action@v4` with `403` or failing to open the release PR after pushing the release branch.
> 
> **Resolution**:
> In GitHub repository settings:
> 1. Go to **Settings** > **Actions** > **General** > **Workflow permissions**.
> 2. Select **Read and write permissions**.
> 3. Check **Allow GitHub Actions to create and approve pull requests**.
> 4. Save changes.
