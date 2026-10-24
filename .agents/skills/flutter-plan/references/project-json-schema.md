# Project JSON Specification Schema (`flutter-plan`)

The `docs/project.json` file serves as the single source of truth for app architecture and configuration:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "project_name": "my_flutter_app",
  "platforms": ["windows", "android", "ios"],
  "state_management": "bloc",
  "di_container": "get_it",
  "networking": "dio",
  "i18n": {
    "default_locale": "en",
    "supported_locales": ["en", "fa"],
    "rtl_supported": true
  },
  "theming": {
    "design_system": "material_3",
    "supports_dark_mode": true
  }
}
```
