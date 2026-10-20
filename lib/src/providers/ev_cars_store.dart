import '../ha_client/ha_websocket_client.dart';

/// One EV card's entity mapping — a display name plus the HA entities that
/// make it live. All entity fields are optional; an unset one just leaves
/// that reading out of the card.
class EvCarConfig {
  const EvCarConfig({
    required this.name,
    this.batterySocEntityId,
    this.rangeEntityId,
    this.chargingEntityId,
    this.plugConnectedEntityId,
    this.chargeLimitEntityId,
    this.chargePowerEntityId,
  });

  final String name;

  /// Battery state of charge, 0-100.
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

  bool isUnconfigured(String fallbackName) =>
      name == fallbackName &&
      batterySocEntityId == null &&
      rangeEntityId == null &&
      chargingEntityId == null &&
      plugConnectedEntityId == null &&
      chargeLimitEntityId == null &&
      chargePowerEntityId == null;

  factory EvCarConfig.fromJson(Map<String, dynamic> json, {required String fallbackName}) => EvCarConfig(
    // A saved car without a name is named after its battery entity (see
    // the kiosk's evCarsProvider), not one of the built-in defaults.
    name: json['name'] as String? ?? '',
    batterySocEntityId: json['batterySocEntityId'] as String?,
    rangeEntityId: json['rangeEntityId'] as String?,
    chargingEntityId: json['chargingEntityId'] as String?,
    plugConnectedEntityId: json['plugConnectedEntityId'] as String?,
    chargeLimitEntityId: json['chargeLimitEntityId'] as String?,
    chargePowerEntityId: json['chargePowerEntityId'] as String?,
  );
}

/// The kiosk's two EV cards, left and right — a fixed pair, as configured
/// in the HA sidebar panel.
class EvCarsConfig {
  const EvCarsConfig({required this.left, required this.right});

  final EvCarConfig left;
  final EvCarConfig right;

  /// True when nothing has been saved yet, so hydration doesn't clobber a
  /// demo-mode override with blank defaults.
  bool get isEmpty => left.isUnconfigured(defaults.left.name) && right.isUnconfigured(defaults.right.name);

  static const defaults = EvCarsConfig(
    left: EvCarConfig(name: 'Renault Mégane E-Tech'),
    right: EvCarConfig(name: 'Tesla Model Y'),
  );

  factory EvCarsConfig.fromJson(Map<String, dynamic> json) {
    final leftJson = (json['left'] as Map?)?.cast<String, dynamic>();
    final rightJson = (json['right'] as Map?)?.cast<String, dynamic>();
    return EvCarsConfig(
      left: leftJson == null ? defaults.left : EvCarConfig.fromJson(leftJson, fallbackName: defaults.left.name),
      right: rightJson == null ? defaults.right : EvCarConfig.fromJson(rightJson, fallbackName: defaults.right.name),
    );
  }
}

/// Reads [EvCarsConfig] as saved by the HA sidebar panel.
class EvCarsStore {
  EvCarsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'ev_cars';

  Future<EvCarsConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return EvCarsConfig.defaults;
    return EvCarsConfig.fromJson(raw.cast<String, dynamic>());
  }
}
