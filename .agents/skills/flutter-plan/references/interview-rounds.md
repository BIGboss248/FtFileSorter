# Interview Rounds & Probing Questions (`flutter-plan`)

## Round 1: Target Platforms & Desktop Ergonomics

1. Which platforms are you targeting? (Windows Desktop, macOS, Linux, Android, iOS, Web)
2. For desktop apps:
   - Does the app require custom title bars or window sizing limits (`window_manager`)?
   - Does the app need to interact with the local file system or an offline SQLite database?
   - Is system tray integration required?

## Round 2: Architecture, State & Networking

1. State management: Do you want standard BLoC / Cubit architecture?
2. Networking: Are you connecting to a REST API (`dio`), GraphQL, or running purely local offline logic?
3. Caching: Is offline persistence required (SQLite, Hive, or SharedPreferences)?

## Round 3: Design Language & Internationalization

1. UI Kit: Do you prefer standard Material 3 or Windows 11 Fluent Design (`fluent_ui`)?
2. Theming: Should the app support Light and Dark mode with custom semantic tokens?
3. Localization: What languages and locales are supported? Is RTL (e.g. Persian/Arabic) support required?
