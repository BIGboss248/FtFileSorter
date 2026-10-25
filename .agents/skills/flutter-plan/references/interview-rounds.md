# Interview Rounds & Probing Questions (`flutter-plan`)

Before generating plans, the agent inspects `docs/project.json`. **If a property is already defined in `docs/project.json`, the corresponding question MUST be skipped.** Only conduct interview rounds for missing, incomplete, or ambiguous items.

---

## Pre-Flight Check: Inspect `docs/project.json`

Check if `docs/project.json` exists in the workspace:
1. **If present and fully populated**: Validate that `platforms`, `state_management`, `i18n`, and `theming` (with `color_palettes` and `semantic_tokens`) are declared. Skip directly to generating the 6-phase roadmap.
2. **If missing or incomplete**: Conduct the targeted questions below for only the missing sections, write/update `docs/project.json`, and proceed.

---

## Round 1: Target Platforms & Desktop Ergonomics
*(Skip if `platforms` and `platform_settings` are already defined in `docs/project.json`)*

1. Which platforms are you targeting? (Windows Desktop, macOS, Linux, Android, iOS, Web)
2. For desktop apps:
   - Does the app require window sizing constraints or state persistence (`window_manager`)?
   - Does the app need local file system access, offline database (`sqlite3`), or system tray integration?

---

## Round 2: Architecture, State Management & Networking
*(Skip if `state_management`, `di_container`, and `networking` are already defined in `docs/project.json`)*

1. State management preference: BLoC / Cubit (standard) vs Riverpod?
2. Networking: REST API (`dio`), GraphQL, or purely offline local data?
3. Local persistence: SQLite (`sqlite3` / `drift`), Hive, or `shared_preferences`?

---

## Round 3: Theming, Color Palettes & Localization
*(Skip if `theming` and `i18n` are already defined in `docs/project.json`)*

1. Design system: Material 3 vs Windows 11 Fluent Design (`fluent_ui`)?
2. Color Palettes: Do you have primary, secondary, surface, background, and accent hex codes for Light and Dark themes?
3. Custom Semantic Tokens: What extra theme tokens are needed (e.g. `cardBorder`, `accentSubtle`, `statusSuccess`) for `ThemeExtension`?
4. Localization: What are the default and supported locales (e.g. `en`, `fa`)? Is RTL directionality support required?
