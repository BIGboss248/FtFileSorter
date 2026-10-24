# 6-Phase Roadmap Guidelines (`flutter-plan`)

Implementation plans generated in `docs/plan/` follow 6 chronological phases:

- `01-environment-and-tooling.md`: Dependencies, flavors (`dev`, `prod`), static analysis rules, VS Code launch targets.
- `02-architecture-and-di.md`: Dependency injection (`get_it`), base HTTP client (`dio`), and sealed `Result<T, Failure>` contracts.
- `03-core-foundations.md`: App theme data, semantic `ThemeExtension` tokens, localization catalogs (`.arb`), and declarative routing (`go_router`).
- `04-data-and-domain-layer.md`: Immutable models (`freezed`), data providers, domain repositories, and isolate wrappers for CPU-bound tasks.
- `05-presentation-and-widgets.md`: Feature screens and widgets with explicit sub-checklist items:
  - Screen Widget (`lib/src/presentation/screens/<feature>_screen.dart`)
  - BLoC/Cubit wiring
  - Loading / Progress state
  - Error recovery state (`ErrorRetryView`)
  - Empty collection state
  - Widget test (`test/presentation/<feature>_test.dart`)
- `06-packaging-and-release.md`: App icons, Windows installer/MSIX packaging, Release Please GitHub Actions automation.
