import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

/// Persists the energy-flow card's individual-sensor list as a single
/// JSON-encoded string — same reasoning as `CalendarEntitiesStore`: a
/// user-grown list (0-4 entries) has no fixed set of `shared_preferences`
/// keys to enumerate.
class IndividualSensorsStore {
  IndividualSensorsStore();

  static const _key = 'energy_individual_sensors';

  Future<List<IndividualSensorConfig>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(IndividualSensorConfig.fromJson).toList();
  }

  /// Capped at 4 — the energy-flow card has exactly 4 device node slots, so
  /// anything beyond that could never be shown.
  Future<void> save(List<IndividualSensorConfig> sensors) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = sensors.where((s) => s.name.trim().isNotEmpty).take(4).toList();
    if (valid.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(valid.map((s) => s.toJson()).toList()));
  }
}
