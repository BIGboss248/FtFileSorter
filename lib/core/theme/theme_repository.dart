import 'package:adaptive_theme/adaptive_theme.dart';

/// Contract for managing app theme mode state and persistence.
abstract interface class IThemeRepository {
  Future<AdaptiveThemeMode> getInitialThemeMode();
  Future<void> setThemeMode(AdaptiveThemeMode mode);
}

/// AdaptiveTheme-backed theme repository.
class AdaptiveThemeRepository implements IThemeRepository {
  const AdaptiveThemeRepository();

  @override
  Future<AdaptiveThemeMode> getInitialThemeMode() async {
    final mode = await AdaptiveTheme.getThemeMode();
    return mode ?? AdaptiveThemeMode.system;
  }

  @override
  Future<void> setThemeMode(AdaptiveThemeMode mode) async {
    // Mode persistence is handled directly by AdaptiveTheme under AdaptiveTheme.prefKey
  }
}
