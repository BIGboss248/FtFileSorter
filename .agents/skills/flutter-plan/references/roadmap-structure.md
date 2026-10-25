# 6-Phase Roadmap Guidelines (`flutter-plan`)

All roadmap markdown files created under `docs/plan/` must be generated specific to the configurations declared in `docs/project.json`.

---

## Phase Mapping from `docs/project.json`

### `01-environment-and-tooling.md`
- **Platforms**: Add platform-specific dependencies (e.g. `window_manager` for desktop platforms in `project.json.platforms`).
- **Core Dependencies**: Add `project.json.state_management.library` (`flutter_bloc`, `flutter_riverpod`), `project.json.di_container` (`get_it`), and `project.json.networking.client` (`dio`).
- **Tooling**: Configure `analysis_options.yaml` with strict lints, VS Code launch configurations for each platform in `project.json.platforms`, and dev/staging/prod build flavors.

### `02-architecture-and-di.md`
- **DI Registration**: Scaffold `lib/src/core/di/injection.dart` using the container in `project.json.di_container`.
- **Client & Storage**: Register instances of `project.json.networking.client` and `project.json.storage.local_database`.
- **Result / Error Contract**: Implement sealed class `Result<T, Failure>` and unified error mapping.

### `03-core-foundations.md`
- **Theming & Color Palettes**:
  - Implement `lib/src/core/theme/color_schemes.dart` with the exact `light` and `dark` hex codes defined in `project.json.theming.color_palettes`.
  - Create `AppThemeExtension extends ThemeExtension<AppThemeExtension>` defining all custom tokens from `project.json.theming.semantic_tokens` with `lerp()` transitions.
  - Implement `ThemeData` builders supporting `project.json.theming.design_system`.
- **Localization (`i18n`)**:
  - Configure `l10n.yaml` with `arb-dir: lib/l10n` and `template-arb-file: app_en.arb`.
  - Create ARB catalogs for all `project.json.i18n.supported_locales` (e.g., `app_en.arb`, `app_fa.arb`).
  - If `project.json.i18n.rtl_supported` is true, enforce directional padding (`EdgeInsetsDirectional`) and test RTL layouts.
- **Routing**: Set up `MaterialApp.router` using `go_router` with declarative route paths.

### `04-data-and-domain-layer.md`
- **Models & Serialization**: Generate immutable entity models.
- **Repositories**: Create repository interfaces and concrete data sources consuming `project.json.storage` and `project.json.networking`.
- **State Layer**: Implement state units using `project.json.state_management.library` (e.g. `Bloc` / `Cubit` event/state hierarchy).
- **Background Isolates**: Wrap compute-heavy operations (large JSON decoding, heavy file scans) in `Isolate.run()` to prevent frame drops.

### `05-presentation-and-widgets.md`
- Feature checklists for every screen with sub-items:
  - Screen Widget (`lib/src/presentation/screens/<feature>_screen.dart`) with desktop/mobile adaptive layouts matching `project.json.platforms`.
  - State Consumer/Listener wired to `project.json.state_management.library`.
  - Theme consumption using `Theme.of(context).colorScheme` and `Theme.of(context).extension<AppThemeExtension>()`.
  - All user-facing strings bound to `AppLocalizations.of(context)!` (no hardcoded strings).
  - Loading skeleton state (`<feature>_skeleton.dart`).
  - Error recovery state with retry button.
  - Empty collection state.
  - Component widget test (`test/presentation/<feature>_test.dart`).

### `06-packaging-and-release.md`
- Scaffold build & release automation specific to `project.json.platforms`:
  - **Windows**: Inno Setup (`windows/installer/setup.iss`) or MSIX packaging (`msix_config`), single-command desktop packaging.
  - **Android / iOS**: App bundles (`aab`), keystore configurations, provisioning profiles.
  - **CI/CD**: GitHub Actions matrix workflow building release artifacts for every platform listed in `project.json.platforms`.
