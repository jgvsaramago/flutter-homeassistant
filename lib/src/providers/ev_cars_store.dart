import '../ha_client/ha_websocket_client.dart';

enum CarKind { electric, fuel }

/// One car's entity mapping — a display name, whether it's electric or
/// runs on fuel, and the HA entities that make its card live. All entity
/// fields are optional; an unset one just leaves that reading out.
class CarConfig {
  const CarConfig({
    required this.name,
    this.kind = CarKind.electric,
    this.homeEntityId,
    this.batterySocEntityId,
    this.rangeEntityId,
    this.chargingEntityId,
    this.plugConnectedEntityId,
    this.chargeLimitEntityId,
    this.chargePowerEntityId,
    this.fuelEntityId,
    this.lockEntityId,
  });

  final String name;
  final CarKind kind;

  /// `device_tracker.*`, `person.*` or `binary_sensor.*` saying the car is
  /// at home. The screen shows the first two cars at home; unset means
  /// always shown.
  final String? homeEntityId;

  /// Battery state of charge, 0-100 (electric).
  final String? batterySocEntityId;

  /// Remaining range, in whatever unit the sensor reports.
  final String? rangeEntityId;

  /// Any entity whose state means "charging" when `on`/`charging`/`true`.
  final String? chargingEntityId;

  /// "Is the cable plugged in" — distinct from charging, since a full
  /// battery stays plugged in without drawing current. Renault's enum
  /// sensor (`plugged`, `plugged_waiting_for_charge`, `unplugged`) works.
  final String? plugConnectedEntityId;

  /// The charge limit the car stops at, 0-100 — the marker on the card's
  /// battery bar.
  final String? chargeLimitEntityId;

  /// Charging power (W or kW, auto-detected) — shown while charging.
  final String? chargePowerEntityId;

  /// Fuel left, % of the tank (fuel).
  final String? fuelEntityId;

  /// `lock.*` or `binary_sensor.*` (on = unlocked) for "Trancado" (fuel).
  final String? lockEntityId;

  List<String?> get entityIds => [
    homeEntityId,
    batterySocEntityId,
    rangeEntityId,
    chargingEntityId,
    plugConnectedEntityId,
    chargeLimitEntityId,
    chargePowerEntityId,
    fuelEntityId,
    lockEntityId,
  ];

  bool get isBlank => name.trim().isEmpty && entityIds.every((id) => id == null);

  factory CarConfig.fromJson(Map<String, dynamic> json) {
    String? id(String k) {
      final v = json[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return CarConfig(
      // A car without a name is named after its battery entity (see the
      // kiosk's carsProvider).
      name: json['name'] as String? ?? '',
      kind: json['kind'] == 'fuel' ? CarKind.fuel : CarKind.electric,
      homeEntityId: id('homeEntityId'),
      batterySocEntityId: id('batterySocEntityId'),
      rangeEntityId: id('rangeEntityId'),
      chargingEntityId: id('chargingEntityId'),
      plugConnectedEntityId: id('plugConnectedEntityId'),
      chargeLimitEntityId: id('chargeLimitEntityId'),
      chargePowerEntityId: id('chargePowerEntityId'),
      fuelEntityId: id('fuelEntityId'),
      lockEntityId: id('lockEntityId'),
    );
  }
}

/// The house's cars, in the order chosen in the HA sidebar panel.
class CarsConfig {
  const CarsConfig(this.cars);

  final List<CarConfig> cars;

  /// True when nothing has been saved yet, so hydration doesn't clobber a
  /// demo-mode override.
  bool get isEmpty => cars.isEmpty;

  static const empty = CarsConfig([]);

  /// A list, or — saved before cars became a list — the old fixed
  /// `{left, right}` pair of electric cars.
  factory CarsConfig.fromJson(Object? raw) {
    if (raw is List) {
      return CarsConfig([for (final c in raw.whereType<Map>()) CarConfig.fromJson(c.cast<String, dynamic>())]);
    }
    if (raw is Map) {
      return CarsConfig(
        [
          for (final slot in ['left', 'right'])
            if (raw[slot] case final Map c) CarConfig.fromJson(c.cast<String, dynamic>()),
        ].where((c) => !c.isBlank).toList(),
      );
    }
    return empty;
  }
}

/// Reads [CarsConfig] as saved by the HA sidebar panel.
class CarsStore {
  CarsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'ev_cars';

  Future<CarsConfig> read() async => CarsConfig.fromJson(await _client.getSettings(_key));
}
