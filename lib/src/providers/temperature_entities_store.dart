import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

/// Which HA entities feed the Temperatures sheet. All optional — an unset
/// field just makes that metric show "--" until configured. The two
/// temperature fields default to this app's own pre-existing hardcoded
/// sensors (the ones `ClimateModeRow`'s card already read before this
/// config existed), so upgrading doesn't blank out the one thing that was
/// already working.
class TemperatureEntityConfig {
  const TemperatureEntityConfig({
    this.interiorTempEntityId = 'sensor.temperatura_media_casa_piso_0',
    this.interiorHumidityEntityId,
    this.co2EntityId,
    this.pm25EntityId,
    this.vocEntityId,
    this.radonEntityId,
    this.exteriorTempEntityId = 'sensor.sotao_gw2000a_wifiee57_outdoor_temperature',
    this.exteriorHumidityEntityId,
    this.rainEntityId,
    this.windEntityId,
    this.gustEntityId,
    this.pressureEntityId,
    this.uvEntityId,
    this.weatherStateEntityId,
  });

  final String? interiorTempEntityId;
  final String? interiorHumidityEntityId;
  final String? co2EntityId;
  final String? pm25EntityId;
  final String? vocEntityId;
  final String? radonEntityId;

  final String? exteriorTempEntityId;
  final String? exteriorHumidityEntityId;
  final String? rainEntityId;
  final String? windEntityId;
  final String? gustEntityId;
  final String? pressureEntityId;
  final String? uvEntityId;
  final String? weatherStateEntityId;

  TemperatureEntityConfig copyWith({
    String? interiorTempEntityId,
    String? interiorHumidityEntityId,
    String? co2EntityId,
    String? pm25EntityId,
    String? vocEntityId,
    String? radonEntityId,
    String? exteriorTempEntityId,
    String? exteriorHumidityEntityId,
    String? rainEntityId,
    String? windEntityId,
    String? gustEntityId,
    String? pressureEntityId,
    String? uvEntityId,
    String? weatherStateEntityId,
  }) {
    return TemperatureEntityConfig(
      interiorTempEntityId: interiorTempEntityId ?? this.interiorTempEntityId,
      interiorHumidityEntityId: interiorHumidityEntityId ?? this.interiorHumidityEntityId,
      co2EntityId: co2EntityId ?? this.co2EntityId,
      pm25EntityId: pm25EntityId ?? this.pm25EntityId,
      vocEntityId: vocEntityId ?? this.vocEntityId,
      radonEntityId: radonEntityId ?? this.radonEntityId,
      exteriorTempEntityId: exteriorTempEntityId ?? this.exteriorTempEntityId,
      exteriorHumidityEntityId: exteriorHumidityEntityId ?? this.exteriorHumidityEntityId,
      rainEntityId: rainEntityId ?? this.rainEntityId,
      windEntityId: windEntityId ?? this.windEntityId,
      gustEntityId: gustEntityId ?? this.gustEntityId,
      pressureEntityId: pressureEntityId ?? this.pressureEntityId,
      uvEntityId: uvEntityId ?? this.uvEntityId,
      weatherStateEntityId: weatherStateEntityId ?? this.weatherStateEntityId,
    );
  }

  Map<String, dynamic> toJson() => {
    'interiorTempEntityId': interiorTempEntityId,
    'interiorHumidityEntityId': interiorHumidityEntityId,
    'co2EntityId': co2EntityId,
    'pm25EntityId': pm25EntityId,
    'vocEntityId': vocEntityId,
    'radonEntityId': radonEntityId,
    'exteriorTempEntityId': exteriorTempEntityId,
    'exteriorHumidityEntityId': exteriorHumidityEntityId,
    'rainEntityId': rainEntityId,
    'windEntityId': windEntityId,
    'gustEntityId': gustEntityId,
    'pressureEntityId': pressureEntityId,
    'uvEntityId': uvEntityId,
    'weatherStateEntityId': weatherStateEntityId,
  };

  factory TemperatureEntityConfig.fromJson(Map<String, dynamic> json) => TemperatureEntityConfig(
    interiorTempEntityId: json['interiorTempEntityId'] as String? ?? const TemperatureEntityConfig().interiorTempEntityId,
    interiorHumidityEntityId: json['interiorHumidityEntityId'] as String?,
    co2EntityId: json['co2EntityId'] as String?,
    pm25EntityId: json['pm25EntityId'] as String?,
    vocEntityId: json['vocEntityId'] as String?,
    radonEntityId: json['radonEntityId'] as String?,
    exteriorTempEntityId: json['exteriorTempEntityId'] as String? ?? const TemperatureEntityConfig().exteriorTempEntityId,
    exteriorHumidityEntityId: json['exteriorHumidityEntityId'] as String?,
    rainEntityId: json['rainEntityId'] as String?,
    windEntityId: json['windEntityId'] as String?,
    gustEntityId: json['gustEntityId'] as String?,
    pressureEntityId: json['pressureEntityId'] as String?,
    uvEntityId: json['uvEntityId'] as String?,
    weatherStateEntityId: json['weatherStateEntityId'] as String?,
  );
}

/// Persists [TemperatureEntityConfig] via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same entities.
class TemperatureEntitiesStore {
  TemperatureEntitiesStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'temperature_entities';

  Future<TemperatureEntityConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const TemperatureEntityConfig();
    return TemperatureEntityConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> save(TemperatureEntityConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
