import 'package:shared_preferences/shared_preferences.dart';

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
}

/// Persists [TemperatureEntityConfig] via `shared_preferences` — same
/// storage and reasoning as `EnergyEntitiesStore`.
class TemperatureEntitiesStore {
  TemperatureEntitiesStore();

  static const _defaults = TemperatureEntityConfig();

  static const _keys = {
    'interiorTempEntityId': 'temp_interior_temp_entity_id',
    'interiorHumidityEntityId': 'temp_interior_humidity_entity_id',
    'co2EntityId': 'temp_co2_entity_id',
    'pm25EntityId': 'temp_pm25_entity_id',
    'vocEntityId': 'temp_voc_entity_id',
    'radonEntityId': 'temp_radon_entity_id',
    'exteriorTempEntityId': 'temp_exterior_temp_entity_id',
    'exteriorHumidityEntityId': 'temp_exterior_humidity_entity_id',
    'rainEntityId': 'temp_rain_entity_id',
    'windEntityId': 'temp_wind_entity_id',
    'gustEntityId': 'temp_gust_entity_id',
    'pressureEntityId': 'temp_pressure_entity_id',
    'uvEntityId': 'temp_uv_entity_id',
    'weatherStateEntityId': 'temp_weather_state_entity_id',
  };

  Future<TemperatureEntityConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    String? get(String field, String? fallback) => prefs.getString(_keys[field]!) ?? fallback;

    return TemperatureEntityConfig(
      interiorTempEntityId: get('interiorTempEntityId', _defaults.interiorTempEntityId),
      interiorHumidityEntityId: get('interiorHumidityEntityId', null),
      co2EntityId: get('co2EntityId', null),
      pm25EntityId: get('pm25EntityId', null),
      vocEntityId: get('vocEntityId', null),
      radonEntityId: get('radonEntityId', null),
      exteriorTempEntityId: get('exteriorTempEntityId', _defaults.exteriorTempEntityId),
      exteriorHumidityEntityId: get('exteriorHumidityEntityId', null),
      rainEntityId: get('rainEntityId', null),
      windEntityId: get('windEntityId', null),
      gustEntityId: get('gustEntityId', null),
      pressureEntityId: get('pressureEntityId', null),
      uvEntityId: get('uvEntityId', null),
      weatherStateEntityId: get('weatherStateEntityId', null),
    );
  }

  Future<void> save(TemperatureEntityConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await _setOrRemove(prefs, _keys['interiorTempEntityId']!, config.interiorTempEntityId);
    await _setOrRemove(prefs, _keys['interiorHumidityEntityId']!, config.interiorHumidityEntityId);
    await _setOrRemove(prefs, _keys['co2EntityId']!, config.co2EntityId);
    await _setOrRemove(prefs, _keys['pm25EntityId']!, config.pm25EntityId);
    await _setOrRemove(prefs, _keys['vocEntityId']!, config.vocEntityId);
    await _setOrRemove(prefs, _keys['radonEntityId']!, config.radonEntityId);
    await _setOrRemove(prefs, _keys['exteriorTempEntityId']!, config.exteriorTempEntityId);
    await _setOrRemove(prefs, _keys['exteriorHumidityEntityId']!, config.exteriorHumidityEntityId);
    await _setOrRemove(prefs, _keys['rainEntityId']!, config.rainEntityId);
    await _setOrRemove(prefs, _keys['windEntityId']!, config.windEntityId);
    await _setOrRemove(prefs, _keys['gustEntityId']!, config.gustEntityId);
    await _setOrRemove(prefs, _keys['pressureEntityId']!, config.pressureEntityId);
    await _setOrRemove(prefs, _keys['uvEntityId']!, config.uvEntityId);
    await _setOrRemove(prefs, _keys['weatherStateEntityId']!, config.weatherStateEntityId);
  }

  Future<void> _setOrRemove(SharedPreferences prefs, String key, String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? prefs.remove(key) : prefs.setString(key, trimmed);
  }
}
