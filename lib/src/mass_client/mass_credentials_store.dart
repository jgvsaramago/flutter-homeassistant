import '../ha_client/ha_websocket_client.dart';
import '../providers/settings_json_utils.dart';
import 'mass_connection_config.dart';

/// Persists the Music Assistant server URL/token via the `flutter_homeassistant`
/// HA integration, so any device running this app shares the same server —
/// same reasoning as the other dashboard-config stores. Unlike the HA
/// connection itself, this can live in HA storage: by the time the app needs
/// it, it's already connected to HA.
class MassCredentialsStore {
  MassCredentialsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'music_assistant';

  Future<MassConnectionConfig?> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    if (json['baseUrl'] == null || json['accessToken'] == null) return null;
    return MassConnectionConfig.fromJson(json);
  }

  Future<void> save(MassConnectionConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
