import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

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

  Map<String, dynamic> toJson() => {
    'gridPowerEntityId': gridPowerEntityId,
    'solarPowerEntityId': solarPowerEntityId,
    'batteryPowerEntityId': batteryPowerEntityId,
    'batterySocEntityId': batterySocEntityId,
    'homePowerEntityId': homePowerEntityId,
    'gridZeroThresholdW': gridZeroThresholdW,
    'solarZeroThresholdW': solarZeroThresholdW,
    'batteryZeroThresholdW': batteryZeroThresholdW,
    'homeZeroThresholdW': homeZeroThresholdW,
  };

  factory EnergyEntityConfig.fromJson(Map<String, dynamic> json) {
    const defaults = EnergyEntityConfig();
    return EnergyEntityConfig(
      gridPowerEntityId: json['gridPowerEntityId'] as String?,
      solarPowerEntityId: json['solarPowerEntityId'] as String?,
      batteryPowerEntityId: json['batteryPowerEntityId'] as String?,
      batterySocEntityId: json['batterySocEntityId'] as String?,
      homePowerEntityId: json['homePowerEntityId'] as String?,
      gridZeroThresholdW: (json['gridZeroThresholdW'] as num?)?.toDouble() ?? defaults.gridZeroThresholdW,
      solarZeroThresholdW: (json['solarZeroThresholdW'] as num?)?.toDouble() ?? defaults.solarZeroThresholdW,
      batteryZeroThresholdW: (json['batteryZeroThresholdW'] as num?)?.toDouble() ?? defaults.batteryZeroThresholdW,
      homeZeroThresholdW: (json['homeZeroThresholdW'] as num?)?.toDouble() ?? defaults.homeZeroThresholdW,
    );
  }
}

/// Persists [EnergyEntityConfig] via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same entities.
class EnergyEntitiesStore {
  EnergyEntitiesStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'energy_entities';

  Future<EnergyEntityConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const EnergyEntityConfig();
    return EnergyEntityConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> save(EnergyEntityConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
