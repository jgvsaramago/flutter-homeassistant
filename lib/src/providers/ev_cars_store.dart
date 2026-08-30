import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

/// One EV card's entity mapping — a display name plus the three HA entities
/// that make it live. All entity fields are optional; an unset one just
/// makes that reading show "--" on the card until configured, same as the
/// energy-flow card's own nodes.
class EvCarConfig {
  const EvCarConfig({
    required this.name,
    this.batterySocEntityId,
    this.rangeEntityId,
    this.chargingEntityId,
    this.plugConnectedEntityId,
    this.monthEnergyEntityId,
    this.monthEnergyDeltaEntityId,
    this.monthCostEntityId,
    this.monthCostDeltaEntityId,
    this.photoUrl,
  });

  final String name;

  /// Battery state of charge, 0-100.
  final String? batterySocEntityId;

  /// Remaining range — read as-is, whatever unit the sensor reports in
  /// (this app does no km/mi conversion, same as every other distance
  /// reading elsewhere in the dashboard).
  final String? rangeEntityId;

  /// Any entity whose state means "charging" when `on`/`charging`/`true` —
  /// a `binary_sensor` is the common case, but a text `sensor` with one of
  /// those states works too.
  final String? chargingEntityId;

  /// Same `on`/`connected`/`true` truthiness as [chargingEntityId], but for
  /// "is the cable plugged in" — distinct from actually charging, since a
  /// full battery stays plugged in without drawing current.
  final String? plugConnectedEntityId;

  /// kWh charged this calendar month — a `utility_meter`-style sensor that
  /// resets monthly. Feeds both the EV sheet's "Energia" stat card and the
  /// current month's bar in its 6-month chart.
  final String? monthEnergyEntityId;

  /// Percent change vs the previous month, as a plain signed/unsigned
  /// number (e.g. `17` or `-18`) — this app adds the `%`/sign/colour itself.
  final String? monthEnergyDeltaEntityId;

  /// Cost of this calendar month's charging, in euros.
  final String? monthCostEntityId;

  /// Change vs the previous month's cost, in euros, signed the same way as
  /// [monthEnergyDeltaEntityId].
  final String? monthCostDeltaEntityId;

  /// A plain image URL — this app has no in-app photo upload/picker (the
  /// kiosk's flutter-pi embedder has no platform channel for one anyway),
  /// so a car photo is whatever URL already serves it: a file dropped in
  /// HA's `/config/www/` (served at `http://<ha>/local/...`), an
  /// `entity_picture` copied from a `camera`/`image`/`person` entity, or
  /// any other reachable image host. Rendered with `Image.network`, same
  /// as album art elsewhere in this app (see `music_sheet.dart`).
  final String? photoUrl;

  /// True when nothing distinguishes this car from [fallbackName] with no
  /// entities configured — i.e. this is what `EvCarsStore.read()` returns
  /// when nothing has ever been saved, as opposed to a real save that
  /// happens to leave every entity unset. [fallbackName] must be the
  /// matching side's own default name ([EvCarsConfig.defaults].left/right),
  /// since the two sides don't share one.
  bool isUnconfigured(String fallbackName) =>
      name == fallbackName &&
      batterySocEntityId == null &&
      rangeEntityId == null &&
      chargingEntityId == null &&
      plugConnectedEntityId == null &&
      monthEnergyEntityId == null &&
      monthEnergyDeltaEntityId == null &&
      monthCostEntityId == null &&
      monthCostDeltaEntityId == null &&
      photoUrl == null;

  EvCarConfig copyWith({
    String? name,
    String? batterySocEntityId,
    String? rangeEntityId,
    String? chargingEntityId,
    String? plugConnectedEntityId,
    String? monthEnergyEntityId,
    String? monthEnergyDeltaEntityId,
    String? monthCostEntityId,
    String? monthCostDeltaEntityId,
    String? photoUrl,
  }) {
    return EvCarConfig(
      name: name ?? this.name,
      batterySocEntityId: batterySocEntityId ?? this.batterySocEntityId,
      rangeEntityId: rangeEntityId ?? this.rangeEntityId,
      chargingEntityId: chargingEntityId ?? this.chargingEntityId,
      plugConnectedEntityId:
          plugConnectedEntityId ?? this.plugConnectedEntityId,
      monthEnergyEntityId: monthEnergyEntityId ?? this.monthEnergyEntityId,
      monthEnergyDeltaEntityId:
          monthEnergyDeltaEntityId ?? this.monthEnergyDeltaEntityId,
      monthCostEntityId: monthCostEntityId ?? this.monthCostEntityId,
      monthCostDeltaEntityId:
          monthCostDeltaEntityId ?? this.monthCostDeltaEntityId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'batterySocEntityId': batterySocEntityId,
    'rangeEntityId': rangeEntityId,
    'chargingEntityId': chargingEntityId,
    'plugConnectedEntityId': plugConnectedEntityId,
    'monthEnergyEntityId': monthEnergyEntityId,
    'monthEnergyDeltaEntityId': monthEnergyDeltaEntityId,
    'monthCostEntityId': monthCostEntityId,
    'monthCostDeltaEntityId': monthCostDeltaEntityId,
    'photoUrl': photoUrl,
  };

  factory EvCarConfig.fromJson(Map<String, dynamic> json, {required String fallbackName}) => EvCarConfig(
    name: json['name'] as String? ?? fallbackName,
    batterySocEntityId: json['batterySocEntityId'] as String?,
    rangeEntityId: json['rangeEntityId'] as String?,
    chargingEntityId: json['chargingEntityId'] as String?,
    plugConnectedEntityId: json['plugConnectedEntityId'] as String?,
    monthEnergyEntityId: json['monthEnergyEntityId'] as String?,
    monthEnergyDeltaEntityId: json['monthEnergyDeltaEntityId'] as String?,
    monthCostEntityId: json['monthCostEntityId'] as String?,
    monthCostDeltaEntityId: json['monthCostDeltaEntityId'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );
}

/// The Homepage's two EV cards, left and right — a fixed pair (this design
/// has exactly two slots, not an arbitrary list) rather than a `List<EvCarConfig>`.
class EvCarsConfig {
  const EvCarsConfig({required this.left, required this.right});

  final EvCarConfig left;
  final EvCarConfig right;

  /// True when this is exactly what an unconfigured install looks like —
  /// see [EvCarConfig.isUnconfigured]. `RootScreen`'s bootstrap uses this to
  /// tell "nothing saved yet" apart from a real save, so it doesn't clobber
  /// whatever set [evCarsConfigProvider] before the saved value loaded (an
  /// override in demo mode, chiefly).
  bool get isEmpty => left.isUnconfigured(defaults.left.name) && right.isUnconfigured(defaults.right.name);

  /// This household's two cars — the only names baked into this app (unlike
  /// the energy/temperature cards, which start fully unconfigured), since a
  /// name is display copy, not an HA integration detail.
  static const defaults = EvCarsConfig(
    left: EvCarConfig(name: 'Renault Mégane E-Tech'),
    right: EvCarConfig(name: 'Tesla Model Y'),
  );

  EvCarsConfig copyWith({EvCarConfig? left, EvCarConfig? right}) =>
      EvCarsConfig(left: left ?? this.left, right: right ?? this.right);

  Map<String, dynamic> toJson() => {'left': left.toJson(), 'right': right.toJson()};

  factory EvCarsConfig.fromJson(Map<String, dynamic> json) {
    final leftJson = (json['left'] as Map?)?.cast<String, dynamic>();
    final rightJson = (json['right'] as Map?)?.cast<String, dynamic>();
    return EvCarsConfig(
      left: leftJson == null ? defaults.left : EvCarConfig.fromJson(leftJson, fallbackName: defaults.left.name),
      right: rightJson == null ? defaults.right : EvCarConfig.fromJson(rightJson, fallbackName: defaults.right.name),
    );
  }
}

/// Persists [EvCarsConfig] via the `flutter_homeassistant` HA integration,
/// so any device running this app shares the same two cars.
class EvCarsStore {
  EvCarsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'ev_cars';

  Future<EvCarsConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return EvCarsConfig.defaults;
    return EvCarsConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> save(EvCarsConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
