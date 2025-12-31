import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._(this._prefs, ThemeMode initialMode)
      : themeMode = ValueNotifier<ThemeMode>(initialMode);

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> themeMode;

  static const _kThemeModeKey = 'themeMode';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppSettings._(prefs, mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeModeKey, s);
  }
}
