import 'package:shared_preferences/shared_preferences.dart';

import 'mqtt_config.dart';

/// Persists MQTT broker connection details via `shared_preferences` — same
/// storage and same reasoning as `HaCredentialsStore` (see that class).
class MqttCredentialsStore {
  MqttCredentialsStore();

  static const _hostKey = 'mqtt_host';
  static const _portKey = 'mqtt_port';
  static const _usernameKey = 'mqtt_username';
  static const _passwordKey = 'mqtt_password';

  Future<MqttConfig?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    if (host == null) return null;
    return MqttConfig(
      host: host,
      port: prefs.getInt(_portKey) ?? 1883,
      username: prefs.getString(_usernameKey),
      password: prefs.getString(_passwordKey),
    );
  }

  Future<void> save(MqttConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, config.host);
    await prefs.setInt(_portKey, config.port);
    if (config.username != null) {
      await prefs.setString(_usernameKey, config.username!);
    } else {
      await prefs.remove(_usernameKey);
    }
    if (config.password != null) {
      await prefs.setString(_passwordKey, config.password!);
    } else {
      await prefs.remove(_passwordKey);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }
}
