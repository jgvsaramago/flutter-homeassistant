import 'package:shared_preferences/shared_preferences.dart';

import 'mass_connection_config.dart';

/// Persists the Music Assistant base URL and long-lived access token via
/// `shared_preferences` — same storage and reasoning as `HaCredentialsStore`.
class MassCredentialsStore {
  MassCredentialsStore();

  static const _baseUrlKey = 'mass_base_url';
  static const _accessTokenKey = 'mass_access_token';

  Future<MassConnectionConfig?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey);
    final accessToken = prefs.getString(_accessTokenKey);
    if (baseUrl == null || accessToken == null) return null;
    return MassConnectionConfig(baseUrl: baseUrl, accessToken: accessToken);
  }

  Future<void> save(MassConnectionConfig config) async {
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
