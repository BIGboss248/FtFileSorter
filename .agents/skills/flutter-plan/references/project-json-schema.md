# Project JSON Specification Schema (`flutter-plan`)

The `docs/project.json` file serves as the canonical single source of truth for all architectural and design decisions in the Flutter application. Every phase in `docs/plan/` is generated directly from these declarations.

---

## Canonical JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "project_name": "my_flutter_app",
  "platforms": ["windows", "android", "ios"],
  "platform_settings": {
    "desktop": {
      "window_title": "My Flutter App",
      "min_width": 800,
      "min_height": 600,
      "persist_window_state": true
    }
  },
  "state_management": {
    "library": "bloc",
    "architecture_pattern": "bloc_cubit",
    "code_generation": false
  },
  "di_container": "get_it",
  "networking": {
    "client": "dio",
    "base_url": "https://api.example.com",
    "timeout_seconds": 30
  },
  "storage": {
    "local_database": "sqlite3",
    "key_value_store": "shared_preferences",
    "secure_storage": false
  },
  "i18n": {
    "default_locale": "en",
    "supported_locales": ["en", "fa"],
    "rtl_supported": true,
    "arb_dir": "lib/l10n",
    "template_arb_file": "app_en.arb"
  },
  "theming": {
    "design_system": "material_3",
    "supports_dark_mode": true,
    "color_palettes": {
      "light": {
        "primary": "#0066FF",
        "on_primary": "#FFFFFF",
        "secondary": "#535F70",
        "on_secondary": "#FFFFFF",
        "surface": "#F8F9FA",
        "on_surface": "#1A1C1E",
        "background": "#FFFFFF",
        "on_background": "#1A1C1E",
        "error": "#BA1A1A",
        "on_error": "#FFFFFF"
      },
      "dark": {
        "primary": "#A8C7FA",
        "on_primary": "#00315C",
        "secondary": "#BBC7DB",
        "on_secondary": "#253140",
        "surface": "#1A1C1E",
        "on_surface": "#E2E2E6",
        "background": "#111315",
        "on_background": "#E2E2E6",
        "error": "#FFB4AB",
        "on_error": "#690005"
      }
    },
    "semantic_tokens": [
      {
        "name": "cardBorder",
        "light": "#E0E2E5",
        "dark": "#2E3135"
      },
      {
        "name": "accentSubtle",
        "light": "#EBF2FF",
        "dark": "#162B4D"
      },
      {
        "name": "statusSuccess",
        "light": "#198754",
        "dark": "#75B798"
      }
    ]
  }
}
```

---

## Schema Property Definitions

| Section | Field | Type | Description |
| :--- | :--- | :--- | :--- |
| `project_name` | - | `string` | Machine name of the Flutter package/executable. |
| `platforms` | - | `string[]` | Target compilation targets: `"windows"`, `"macos"`, `"linux"`, `"android"`, `"ios"`, `"web"`. Drives Phase 1 & 6 configurations. |
| `platform_settings` | `desktop` | `object` | Desktop ergonomics: window minimum dimensions, window position persistence, custom titlebars. |
| `state_management` | `library` | `string` | State library (`"bloc"`, `"cubit"`, `"riverpod"`, `"provider"`). Drives Phase 2, 4, and 5 widget listeners. |
| `di_container` | - | `string` | Service locator / DI container (`"get_it"`, `"riverpod"`, `"injectable"`). |
| `networking` | `client` | `string` | HTTP client (`"dio"`, `"http"`, `"offline_only"`), base URLs, and interceptors. |
| `storage` | `local_database` | `string` | Persistence backend (`"sqlite3"`, `"drift"`, `"hive"`, `"shared_preferences"`). |
| `i18n` | `default_locale` | `string` | Base fallback locale code (e.g. `"en"`). |
| `i18n` | `supported_locales`| `string[]` | Array of supported locale codes (e.g. `["en", "fa"]`). Defines required `.arb` catalogs in Phase 3. |
| `i18n` | `rtl_supported` | `boolean` | Whether right-to-left UI directionality handling is enforced. |
| `theming` | `design_system` | `string` | Design language (`"material_3"`, `"fluent_ui"`, `"cupertino"`). |
| `theming` | `color_palettes` | `object` | Exact hex color contracts for `light` and `dark` ColorSchemes. Directly scaffolded in Phase 3. |
| `theming` | `semantic_tokens` | `array` | Custom semantic design tokens compiled into Flutter `ThemeExtension` classes. |
