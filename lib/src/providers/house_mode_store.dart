import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

/// Which HA `input_select` entity backs the Homepage's house-mode chip
/// (e.g. "Casa" / "Fora" / "Férias" / "Noite"). Unset just hides the chip.
class HouseModeConfig {
  const HouseModeConfig({this.entityId});

  final String? entityId;

  bool get isEmpty => entityId == null || entityId!.trim().isEmpty;

  HouseModeConfig copyWith({String? entityId}) => HouseModeConfig(entityId: entityId ?? this.entityId);

  Map<String, dynamic> toJson() => {'entityId': entityId};

  factory HouseModeConfig.fromJson(Map<String, dynamic> json) => HouseModeConfig(entityId: json['entityId'] as String?);
}

/// Persists [HouseModeConfig] via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same entity.
class HouseModeStore {
  HouseModeStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'house_mode';

  Future<HouseModeConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const HouseModeConfig();
    return HouseModeConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> save(HouseModeConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
