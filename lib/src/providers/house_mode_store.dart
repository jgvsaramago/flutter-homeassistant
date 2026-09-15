import '../ha_client/ha_websocket_client.dart';

/// Which HA `input_select`/`select` entity backs the Homepage's house-mode
/// chip (e.g. "Casa" / "Fora" / "Férias" / "Noite"). Unset just hides the
/// chip. Read-only from the app's side — configured via the
/// `flutter_homeassistant` HA integration's own sidebar panel (Definições →
/// Flutter Dashboard → Modo da Casa), not from an in-app settings screen;
/// see that panel's `frontend/flutter-dashboard-panel.js` for the editor.
class HouseModeConfig {
  const HouseModeConfig({this.entityId});

  final String? entityId;

  bool get isEmpty => entityId == null || entityId!.trim().isEmpty;

  factory HouseModeConfig.fromJson(Map<String, dynamic> json) => HouseModeConfig(entityId: json['entityId'] as String?);
}

/// Reads [HouseModeConfig] as saved by the HA sidebar panel, via the
/// `flutter_homeassistant` HA integration's shared settings store.
class HouseModeStore {
  HouseModeStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'house_mode';

  Future<HouseModeConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const HouseModeConfig();
    return HouseModeConfig.fromJson(raw.cast<String, dynamic>());
  }
}
