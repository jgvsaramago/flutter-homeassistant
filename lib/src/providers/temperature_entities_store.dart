import '../ha_client/ha_websocket_client.dart';

/// The outdoor readings the header shows: a temperature sensor (preferred
/// for the big number) and the `weather.*` entity that gives the condition
/// and the forecast. Saved under the old `temperature_entities` key, so the
/// values already chosen in the HA sidebar panel carry over; its other,
/// older fields (indoor air quality, wind, rain…) are no longer read.
class TemperatureEntityConfig {
  const TemperatureEntityConfig({
    this.exteriorTempEntityId = 'sensor.sotao_gw2000a_wifiee57_outdoor_temperature',
    this.weatherStateEntityId,
  });

  final String? exteriorTempEntityId;
  final String? weatherStateEntityId;

  factory TemperatureEntityConfig.fromJson(Map<String, dynamic> json) => TemperatureEntityConfig(
    exteriorTempEntityId: json['exteriorTempEntityId'] as String? ?? const TemperatureEntityConfig().exteriorTempEntityId,
    weatherStateEntityId: json['weatherStateEntityId'] as String?,
  );
}

/// Reads [TemperatureEntityConfig] as saved by the HA sidebar panel.
class TemperatureEntitiesStore {
  TemperatureEntitiesStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'temperature_entities';

  Future<TemperatureEntityConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const TemperatureEntityConfig();
    return TemperatureEntityConfig.fromJson(raw.cast<String, dynamic>());
  }
}
