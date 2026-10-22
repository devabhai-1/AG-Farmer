import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { auto, light, dark }

class ThemeService extends ChangeNotifier {
  static const _key = 'agro_theme_mode';

  AppThemeMode _mode = AppThemeMode.auto;
  bool _ready = false;

  AppThemeMode get mode => _mode;
  bool get ready => _ready;

  ThemeMode get materialMode {
    switch (_mode) {
      case AppThemeMode.auto:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _mode = switch (raw) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.auto,
    };
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners(); // Synchronous 0ms immediate UI switch
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        switch (mode) {
          AppThemeMode.auto => 'auto',
          AppThemeMode.light => 'light',
          AppThemeMode.dark => 'dark',
        },
      );
    } catch (_) {}
  }

  Future<void> cycle() async {
    final next = switch (_mode) {
      AppThemeMode.auto => AppThemeMode.light,
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.auto,
    };
    await setMode(next);
  }
}
