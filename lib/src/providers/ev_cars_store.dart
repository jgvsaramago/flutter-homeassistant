import 'package:shared_preferences/shared_preferences.dart';

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
}

/// Persists [EvCarsConfig] via `shared_preferences` — same storage and
/// reasoning as `EnergyEntitiesStore`.
class EvCarsStore {
  EvCarsStore();

  static const _leftNameKey = 'ev_car_left_name';
  static const _leftBatteryKey = 'ev_car_left_battery_entity_id';
  static const _leftRangeKey = 'ev_car_left_range_entity_id';
  static const _leftChargingKey = 'ev_car_left_charging_entity_id';
  static const _leftPlugKey = 'ev_car_left_plug_entity_id';
  static const _leftMonthEnergyKey = 'ev_car_left_month_energy_entity_id';
  static const _leftMonthEnergyDeltaKey =
      'ev_car_left_month_energy_delta_entity_id';
  static const _leftMonthCostKey = 'ev_car_left_month_cost_entity_id';
  static const _leftMonthCostDeltaKey =
      'ev_car_left_month_cost_delta_entity_id';
  static const _leftPhotoUrlKey = 'ev_car_left_photo_url';
  static const _rightNameKey = 'ev_car_right_name';
  static const _rightBatteryKey = 'ev_car_right_battery_entity_id';
  static const _rightRangeKey = 'ev_car_right_range_entity_id';
  static const _rightChargingKey = 'ev_car_right_charging_entity_id';
  static const _rightPlugKey = 'ev_car_right_plug_entity_id';
  static const _rightMonthEnergyKey = 'ev_car_right_month_energy_entity_id';
  static const _rightMonthEnergyDeltaKey =
      'ev_car_right_month_energy_delta_entity_id';
  static const _rightMonthCostKey = 'ev_car_right_month_cost_entity_id';
  static const _rightMonthCostDeltaKey =
      'ev_car_right_month_cost_delta_entity_id';
  static const _rightPhotoUrlKey = 'ev_car_right_photo_url';

  Future<EvCarsConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = EvCarsConfig.defaults;
    return EvCarsConfig(
      left: EvCarConfig(
        name: prefs.getString(_leftNameKey) ?? defaults.left.name,
        batterySocEntityId: prefs.getString(_leftBatteryKey),
        rangeEntityId: prefs.getString(_leftRangeKey),
        chargingEntityId: prefs.getString(_leftChargingKey),
        plugConnectedEntityId: prefs.getString(_leftPlugKey),
        monthEnergyEntityId: prefs.getString(_leftMonthEnergyKey),
        monthEnergyDeltaEntityId: prefs.getString(_leftMonthEnergyDeltaKey),
        monthCostEntityId: prefs.getString(_leftMonthCostKey),
        monthCostDeltaEntityId: prefs.getString(_leftMonthCostDeltaKey),
        photoUrl: prefs.getString(_leftPhotoUrlKey),
      ),
      right: EvCarConfig(
        name: prefs.getString(_rightNameKey) ?? defaults.right.name,
        batterySocEntityId: prefs.getString(_rightBatteryKey),
        rangeEntityId: prefs.getString(_rightRangeKey),
        chargingEntityId: prefs.getString(_rightChargingKey),
        plugConnectedEntityId: prefs.getString(_rightPlugKey),
        monthEnergyEntityId: prefs.getString(_rightMonthEnergyKey),
        monthEnergyDeltaEntityId: prefs.getString(_rightMonthEnergyDeltaKey),
        monthCostEntityId: prefs.getString(_rightMonthCostKey),
        monthCostDeltaEntityId: prefs.getString(_rightMonthCostDeltaKey),
        photoUrl: prefs.getString(_rightPhotoUrlKey),
      ),
    );
  }

  Future<void> save(EvCarsConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await _setOrRemove(prefs, _leftNameKey, config.left.name);
    await _setOrRemove(prefs, _leftBatteryKey, config.left.batterySocEntityId);
    await _setOrRemove(prefs, _leftRangeKey, config.left.rangeEntityId);
    await _setOrRemove(prefs, _leftChargingKey, config.left.chargingEntityId);
    await _setOrRemove(prefs, _leftPlugKey, config.left.plugConnectedEntityId);
    await _setOrRemove(
      prefs,
      _leftMonthEnergyKey,
      config.left.monthEnergyEntityId,
    );
    await _setOrRemove(
      prefs,
      _leftMonthEnergyDeltaKey,
      config.left.monthEnergyDeltaEntityId,
    );
    await _setOrRemove(prefs, _leftMonthCostKey, config.left.monthCostEntityId);
    await _setOrRemove(
      prefs,
      _leftMonthCostDeltaKey,
      config.left.monthCostDeltaEntityId,
    );
    await _setOrRemove(prefs, _leftPhotoUrlKey, config.left.photoUrl);
    await _setOrRemove(prefs, _rightNameKey, config.right.name);
    await _setOrRemove(
      prefs,
      _rightBatteryKey,
      config.right.batterySocEntityId,
    );
    await _setOrRemove(prefs, _rightRangeKey, config.right.rangeEntityId);
    await _setOrRemove(prefs, _rightChargingKey, config.right.chargingEntityId);
    await _setOrRemove(
      prefs,
      _rightPlugKey,
      config.right.plugConnectedEntityId,
    );
    await _setOrRemove(
      prefs,
      _rightMonthEnergyKey,
      config.right.monthEnergyEntityId,
    );
    await _setOrRemove(
      prefs,
      _rightMonthEnergyDeltaKey,
      config.right.monthEnergyDeltaEntityId,
    );
    await _setOrRemove(
      prefs,
      _rightMonthCostKey,
      config.right.monthCostEntityId,
    );
    await _setOrRemove(
      prefs,
      _rightMonthCostDeltaKey,
      config.right.monthCostDeltaEntityId,
    );
    await _setOrRemove(prefs, _rightPhotoUrlKey, config.right.photoUrl);
  }

  Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? prefs.remove(key)
        : prefs.setString(key, trimmed);
  }
}
