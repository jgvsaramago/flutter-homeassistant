import 'package:shared_preferences/shared_preferences.dart';

import 'ha_connection_config.dart';

/// Persists the Home Assistant base URL and long-lived access token via
/// `shared_preferences`.
///
/// This dashboard is meant to run as a single-user, physically-secured wall
/// panel (e.g. a Raspberry Pi behind glass), so plain local storage is
/// preferred over `flutter_secure_storage`: its Linux backend depends on a
/// D-Bus secret-service daemon (gnome-keyring, kwallet, ...) that a headless
/// kiosk image typically doesn't run, and it has no web implementation at
/// all — both of which matter here since the app is also previewed in a
/// browser during development.
class HaCredentialsStore {
  HaCredentialsStore();

  static const _baseUrlKey = 'ha_base_url';
  static const _accessTokenKey = 'ha_access_token';

  Future<HaConnectionConfig?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey);
    final accessToken = prefs.getString(_accessTokenKey);
    if (baseUrl == null || accessToken == null) return null;
    return HaConnectionConfig(baseUrl: baseUrl, accessToken: accessToken);
  }

  Future<void> save(HaConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, config.baseUrl);
    await prefs.setString(_accessTokenKey, config.accessToken);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_accessTokenKey);
  }
}
