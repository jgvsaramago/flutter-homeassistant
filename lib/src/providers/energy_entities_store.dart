import 'package:shared_preferences/shared_preferences.dart';

/// Which HA entities feed the Homepage's energy-flow card. All optional —
/// an unset field just makes that node show "--" until configured.
class EnergyEntityConfig {
  const EnergyEntityConfig({
    this.gridPowerEntityId,
    this.solarPowerEntityId,
    this.batteryPowerEntityId,
    this.batterySocEntityId,
    this.homePowerEntityId,
    this.gridZeroThresholdW = 10,
    this.solarZeroThresholdW = 10,
    this.batteryZeroThresholdW = 10,
    this.homeZeroThresholdW = 10,
  });

  /// Signed power, positive = importing from the grid.
  final String? gridPowerEntityId;

  /// Solar production (always >= 0).
  final String? solarPowerEntityId;

  /// Signed power, positive = discharging, negative = charging.
  final String? batteryPowerEntityId;

  /// Battery state of charge, 0-100.
  final String? batterySocEntityId;

  /// Whole-home consumption (always >= 0).
  final String? homePowerEntityId;

  /// Readings within this many watts of zero (in either direction) are
  /// snapped to exactly 0 — for the grid, solar, and battery this also
  /// decides when the card treats that node as "not flowing" (no direction
  /// arrow, no highlighted connection). Guards against real sensors that
  /// never quite settle on exact zero (a few watts of standby/measurement
  /// noise) reading as a persistent trickle of import/export.
  final double gridZeroThresholdW;
  final double solarZeroThresholdW;
  final double batteryZeroThresholdW;
  final double homeZeroThresholdW;

  bool get isEmpty =>
      gridPowerEntityId == null &&
      solarPowerEntityId == null &&
      batteryPowerEntityId == null &&
      batterySocEntityId == null &&
      homePowerEntityId == null;

  EnergyEntityConfig copyWith({
    String? gridPowerEntityId,
    String? solarPowerEntityId,
    String? batteryPowerEntityId,
    String? batterySocEntityId,
    String? homePowerEntityId,
    double? gridZeroThresholdW,
    double? solarZeroThresholdW,
    double? batteryZeroThresholdW,
    double? homeZeroThresholdW,
  }) {
    return EnergyEntityConfig(
      gridPowerEntityId: gridPowerEntityId ?? this.gridPowerEntityId,
      solarPowerEntityId: solarPowerEntityId ?? this.solarPowerEntityId,
      batteryPowerEntityId: batteryPowerEntityId ?? this.batteryPowerEntityId,
      batterySocEntityId: batterySocEntityId ?? this.batterySocEntityId,
      homePowerEntityId: homePowerEntityId ?? this.homePowerEntityId,
      gridZeroThresholdW: gridZeroThresholdW ?? this.gridZeroThresholdW,
      solarZeroThresholdW: solarZeroThresholdW ?? this.solarZeroThresholdW,
      batteryZeroThresholdW: batteryZeroThresholdW ?? this.batteryZeroThresholdW,
      homeZeroThresholdW: homeZeroThresholdW ?? this.homeZeroThresholdW,
    );
  }
}

/// Persists [EnergyEntityConfig] via `shared_preferences` — same storage
/// and reasoning as `HaCredentialsStore`/`MqttCredentialsStore`.
class EnergyEntitiesStore {
  EnergyEntitiesStore();

  static const _gridKey = 'energy_grid_power_entity_id';
  static const _solarKey = 'energy_solar_power_entity_id';
  static const _batteryKey = 'energy_battery_power_entity_id';
  static const _batterySocKey = 'energy_battery_soc_entity_id';
  static const _homeKey = 'energy_home_power_entity_id';
  static const _gridThresholdKey = 'energy_grid_zero_threshold_w';
  static const _solarThresholdKey = 'energy_solar_zero_threshold_w';
  static const _batteryThresholdKey = 'energy_battery_zero_threshold_w';
  static const _homeThresholdKey = 'energy_home_zero_threshold_w';

  Future<EnergyEntityConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = EnergyEntityConfig();
    return EnergyEntityConfig(
      gridPowerEntityId: prefs.getString(_gridKey),
      solarPowerEntityId: prefs.getString(_solarKey),
      batteryPowerEntityId: prefs.getString(_batteryKey),
      batterySocEntityId: prefs.getString(_batterySocKey),
      homePowerEntityId: prefs.getString(_homeKey),
      gridZeroThresholdW: prefs.getDouble(_gridThresholdKey) ?? defaults.gridZeroThresholdW,
      solarZeroThresholdW: prefs.getDouble(_solarThresholdKey) ?? defaults.solarZeroThresholdW,
      batteryZeroThresholdW: prefs.getDouble(_batteryThresholdKey) ?? defaults.batteryZeroThresholdW,
      homeZeroThresholdW: prefs.getDouble(_homeThresholdKey) ?? defaults.homeZeroThresholdW,
    );
  }

  Future<void> save(EnergyEntityConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await _setOrRemove(prefs, _gridKey, config.gridPowerEntityId);
    await _setOrRemove(prefs, _solarKey, config.solarPowerEntityId);
    await _setOrRemove(prefs, _batteryKey, config.batteryPowerEntityId);
    await _setOrRemove(prefs, _batterySocKey, config.batterySocEntityId);
    await _setOrRemove(prefs, _homeKey, config.homePowerEntityId);
    await prefs.setDouble(_gridThresholdKey, config.gridZeroThresholdW);
    await prefs.setDouble(_solarThresholdKey, config.solarZeroThresholdW);
    await prefs.setDouble(_batteryThresholdKey, config.batteryZeroThresholdW);
    await prefs.setDouble(_homeThresholdKey, config.homeZeroThresholdW);
  }

  Future<void> _setOrRemove(SharedPreferences prefs, String key, String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? prefs.remove(key) : prefs.setString(key, trimmed);
  }
}
