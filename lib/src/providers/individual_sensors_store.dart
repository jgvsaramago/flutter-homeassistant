import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

/// Which built-in glyph an individual-sensor node draws — a closed set
/// matching the energy-flow card's own icon inventory (see
/// `individual_sensor_icon.dart`), not a free-form icon picker, since this
/// kiosk has no icon browser/upload path.
enum IndividualSensorIconKey { plug, washer, fridge, tv, ac, boiler }

extension IndividualSensorIconKeyLabel on IndividualSensorIconKey {
  String get label => switch (this) {
    IndividualSensorIconKey.plug => 'Genérico',
    IndividualSensorIconKey.washer => 'Máquina de lavar',
    IndividualSensorIconKey.fridge => 'Frigorífico',
    IndividualSensorIconKey.tv => 'TV',
    IndividualSensorIconKey.ac => 'Ar condicionado',
    IndividualSensorIconKey.boiler => 'Termoacumulador (AQS)',
  };
}

/// One "individual sensor" node on the energy-flow card's device column — a
/// household-specific circuit (washing machine, fridge, water heater...) the
/// user points at its own HA power sensor, optionally a temperature sensor
/// too (a hot-water tank's stored temperature, say). Up to 4 of these fill
/// the card's 4 fixed device slots, in the order they're listed.
class IndividualSensorConfig {
  const IndividualSensorConfig({
    required this.name,
    this.powerEntityId,
    this.temperatureEntityId,
    this.icon = IndividualSensorIconKey.plug,
  });

  final String name;

  /// Instantaneous power draw (always >= 0, in W or kW — same
  /// auto-detected unit handling as the card's other power sensors).
  final String? powerEntityId;

  /// Optional secondary reading shown above the icon, e.g. a hot-water
  /// tank's stored temperature. Unset nodes show no temperature line at all.
  final String? temperatureEntityId;

  final IndividualSensorIconKey icon;

  IndividualSensorConfig copyWith({
    String? name,
    String? powerEntityId,
    String? temperatureEntityId,
    IndividualSensorIconKey? icon,
  }) {
    return IndividualSensorConfig(
      name: name ?? this.name,
      powerEntityId: powerEntityId ?? this.powerEntityId,
      temperatureEntityId: temperatureEntityId ?? this.temperatureEntityId,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'powerEntityId': powerEntityId,
    'temperatureEntityId': temperatureEntityId,
    'icon': icon.name,
  };

  factory IndividualSensorConfig.fromJson(Map<String, dynamic> json) => IndividualSensorConfig(
    name: json['name'] as String? ?? '',
    powerEntityId: json['powerEntityId'] as String?,
    temperatureEntityId: json['temperatureEntityId'] as String?,
    icon: IndividualSensorIconKey.values.firstWhere((k) => k.name == json['icon'], orElse: () => IndividualSensorIconKey.plug),
  );
}

/// Persists the energy-flow card's individual-sensor list via the
/// `flutter_homeassistant` HA integration, so any device running this app
/// shares the same list.
class IndividualSensorsStore {
  IndividualSensorsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'individual_sensors';

  Future<List<IndividualSensorConfig>> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>().map(IndividualSensorConfig.fromJson).toList();
  }

  /// Capped at 4 — the energy-flow card has exactly 4 device node slots, so
  /// anything beyond that could never be shown.
  Future<void> save(List<IndividualSensorConfig> sensors) async {
    final valid = sensors.where((s) => s.name.trim().isNotEmpty).take(4).toList();
    await _client.setSettings(_key, blankStringsToNull(valid.map((s) => s.toJson()).toList()));
  }
}
