import 'package:shared_preferences/shared_preferences.dart';

/// Settings specific to the full-page "Energia" tab — installed system
/// facts, tariffs, and the optional entities behind its KPI/forecast/system
/// sections. Separate from [EnergyEntityConfig] (import that file's
/// `energy_entities_store.dart` for the grid/solar/battery/home power
/// entities this page's flow card and hourly charts reuse). Every field
/// here is optional; an unset one just makes that reading show "--" rather
/// than blocking the rest of the page.
class EnergyPageConfig {
  const EnergyPageConfig({
    this.installedKwp,
    this.panelCount,
    this.panelOrientation,
    this.importPricePerKwh,
    this.exportPricePerKwh,
    this.inverterStatusEntityId,
    this.inverterTemperatureEntityId,
    this.inverterEfficiencyEntityId,
    this.weatherEntityId,
    this.lastCleaningDate,
    this.nextCleaningDate,
    this.forecastDayEntityIds = const [null, null, null, null, null, null, null],
  });

  /// Installed panel capacity, kWp — feeds the header subtitle and the
  /// "rendimento" (kWh/kWp) system-strip figure.
  final double? installedKwp;
  final int? panelCount;
  final String? panelOrientation;

  /// €/kWh paid for grid imports — values the "poupança" KPI's self-consumed
  /// solar.
  final double? importPricePerKwh;

  /// €/kWh received for grid exports.
  final double? exportPricePerKwh;

  final String? inverterStatusEntityId;
  final String? inverterTemperatureEntityId;
  final String? inverterEfficiencyEntityId;

  /// Optional `weather.*` entity whose legacy `forecast` attribute supplies
  /// each day's condition icon and high temperature on the 7-day solar
  /// forecast row — the Solcast entities below carry kWh only, no weather
  /// condition.
  final String? weatherEntityId;

  final DateTime? lastCleaningDate;
  final DateTime? nextCleaningDate;

  /// One optional daily-forecast entity per day, index 0 = today .. index 6
  /// = today+6 — e.g. Solcast's `sensor.solcast_pv_forecast_forecast_today`,
  /// `..._tomorrow`, `..._d3` .. `..._d7`. State is that day's forecast
  /// production in kWh; today's entity is also read for its `detailedForecast`
  /// attribute (half-hourly `pv_estimate` values) to drive the hourly
  /// "previsto" bars on the production chart.
  final List<String?> forecastDayEntityIds;

  bool get isEmpty =>
      installedKwp == null &&
      panelCount == null &&
      panelOrientation == null &&
      importPricePerKwh == null &&
      exportPricePerKwh == null &&
      inverterStatusEntityId == null &&
      inverterTemperatureEntityId == null &&
      inverterEfficiencyEntityId == null &&
      weatherEntityId == null &&
      lastCleaningDate == null &&
      nextCleaningDate == null &&
      forecastDayEntityIds.every((e) => e == null);
}

/// Persists [EnergyPageConfig] via `shared_preferences` — fixed keys per
/// field, same convention as `EnergyEntitiesStore`. The settings card builds
/// its own mutable draft rather than round-tripping through a `copyWith` on
/// this class: several fields here are nullable non-`String` types
/// (`double?`, `DateTime?`) where `existing ?? this.existing`-style
/// `copyWith` can never actually clear a field back to null, only ever
/// replace or leave it — the same trap `EnergyEntitiesCard`'s sensor rows
/// sidestep with their own plain mutable `_SensorDraftEntry`.
class EnergyPageSettingsStore {
  EnergyPageSettingsStore();

  static const _installedKwpKey = 'energy_page_installed_kwp';
  static const _panelCountKey = 'energy_page_panel_count';
  static const _panelOrientationKey = 'energy_page_panel_orientation';
  static const _importPriceKey = 'energy_page_import_price_per_kwh';
  static const _exportPriceKey = 'energy_page_export_price_per_kwh';
  static const _inverterStatusKey = 'energy_page_inverter_status_entity_id';
  static const _inverterTemperatureKey = 'energy_page_inverter_temperature_entity_id';
  static const _inverterEfficiencyKey = 'energy_page_inverter_efficiency_entity_id';
  static const _weatherKey = 'energy_page_weather_entity_id';
  static const _lastCleaningKey = 'energy_page_last_cleaning_date';
  static const _nextCleaningKey = 'energy_page_next_cleaning_date';
  static const _forecastDayKeyPrefix = 'energy_page_forecast_day_';

  Future<EnergyPageConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    return EnergyPageConfig(
      installedKwp: prefs.getDouble(_installedKwpKey),
      panelCount: prefs.getInt(_panelCountKey),
      panelOrientation: prefs.getString(_panelOrientationKey),
      importPricePerKwh: prefs.getDouble(_importPriceKey),
      exportPricePerKwh: prefs.getDouble(_exportPriceKey),
      inverterStatusEntityId: prefs.getString(_inverterStatusKey),
      inverterTemperatureEntityId: prefs.getString(_inverterTemperatureKey),
      inverterEfficiencyEntityId: prefs.getString(_inverterEfficiencyKey),
      weatherEntityId: prefs.getString(_weatherKey),
      lastCleaningDate: _parseDate(prefs.getString(_lastCleaningKey)),
      nextCleaningDate: _parseDate(prefs.getString(_nextCleaningKey)),
      forecastDayEntityIds: [for (var i = 0; i < 7; i++) prefs.getString('$_forecastDayKeyPrefix$i')],
    );
  }

  Future<void> save(EnergyPageConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await _setDoubleOrRemove(prefs, _installedKwpKey, config.installedKwp);
    await _setIntOrRemove(prefs, _panelCountKey, config.panelCount);
    await _setStringOrRemove(prefs, _panelOrientationKey, config.panelOrientation);
    await _setDoubleOrRemove(prefs, _importPriceKey, config.importPricePerKwh);
    await _setDoubleOrRemove(prefs, _exportPriceKey, config.exportPricePerKwh);
    await _setStringOrRemove(prefs, _inverterStatusKey, config.inverterStatusEntityId);
    await _setStringOrRemove(prefs, _inverterTemperatureKey, config.inverterTemperatureEntityId);
    await _setStringOrRemove(prefs, _inverterEfficiencyKey, config.inverterEfficiencyEntityId);
    await _setStringOrRemove(prefs, _weatherKey, config.weatherEntityId);
    await _setStringOrRemove(prefs, _lastCleaningKey, config.lastCleaningDate?.toIso8601String());
    await _setStringOrRemove(prefs, _nextCleaningKey, config.nextCleaningDate?.toIso8601String());
    for (var i = 0; i < 7; i++) {
      await _setStringOrRemove(prefs, '$_forecastDayKeyPrefix$i', config.forecastDayEntityIds[i]);
    }
  }

  DateTime? _parseDate(String? raw) => raw == null ? null : DateTime.tryParse(raw);

  Future<void> _setStringOrRemove(SharedPreferences prefs, String key, String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? prefs.remove(key) : prefs.setString(key, trimmed);
  }

  Future<void> _setDoubleOrRemove(SharedPreferences prefs, String key, double? value) {
    return value == null ? prefs.remove(key) : prefs.setDouble(key, value);
  }

  Future<void> _setIntOrRemove(SharedPreferences prefs, String key, int? value) {
    return value == null ? prefs.remove(key) : prefs.setInt(key, value);
  }
}
