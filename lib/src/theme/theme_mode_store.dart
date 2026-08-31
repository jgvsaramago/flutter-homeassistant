import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the chosen theme [Brightness] via `shared_preferences` — same
/// reasoning as `HaCredentialsStore` for why plain local storage over
/// `flutter_secure_storage` (nothing secret here anyway). Local rather than
/// the shared `flutter_homeassistant` HA settings store: this is a
/// per-device physical trait of this one kiosk panel, not shared dashboard
/// configuration, so it belongs alongside the screen brightness/power state
/// this app already keeps locally.
class ThemeModeStore {
  ThemeModeStore();

  static const _key = 'theme_brightness';

  Future<Brightness?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => null,
    };
  }

  Future<void> save(Brightness mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == Brightness.light ? 'light' : 'dark');
  }
}
