import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

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
    this.importPriceEntityId,
    this.exportPriceEntityId,
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

  /// Entity whose state is the current €/kWh paid for grid imports (e.g. a
  /// dynamic tariff/spot-price sensor) — values the "poupança" KPI's
  /// self-consumed solar.
  final String? importPriceEntityId;

  /// Entity whose state is the current €/kWh received for grid exports.
  final String? exportPriceEntityId;

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
      importPriceEntityId == null &&
      exportPriceEntityId == null &&
      inverterStatusEntityId == null &&
      inverterTemperatureEntityId == null &&
      inverterEfficiencyEntityId == null &&
      weatherEntityId == null &&
      lastCleaningDate == null &&
      nextCleaningDate == null &&
      forecastDayEntityIds.every((e) => e == null);

  Map<String, dynamic> toJson() => {
    'installedKwp': installedKwp,
    'panelCount': panelCount,
    'panelOrientation': panelOrientation,
    'importPriceEntityId': importPriceEntityId,
    'exportPriceEntityId': exportPriceEntityId,
    'inverterStatusEntityId': inverterStatusEntityId,
    'inverterTemperatureEntityId': inverterTemperatureEntityId,
    'inverterEfficiencyEntityId': inverterEfficiencyEntityId,
    'weatherEntityId': weatherEntityId,
    'lastCleaningDate': lastCleaningDate?.toIso8601String(),
    'nextCleaningDate': nextCleaningDate?.toIso8601String(),
    'forecastDayEntityIds': forecastDayEntityIds,
  };

  factory EnergyPageConfig.fromJson(Map<String, dynamic> json) {
    final rawForecast = (json['forecastDayEntityIds'] as List?)?.cast<String?>();
    return EnergyPageConfig(
      installedKwp: (json['installedKwp'] as num?)?.toDouble(),
      panelCount: json['panelCount'] as int?,
      panelOrientation: json['panelOrientation'] as String?,
      importPriceEntityId: json['importPriceEntityId'] as String?,
      exportPriceEntityId: json['exportPriceEntityId'] as String?,
      inverterStatusEntityId: json['inverterStatusEntityId'] as String?,
      inverterTemperatureEntityId: json['inverterTemperatureEntityId'] as String?,
      inverterEfficiencyEntityId: json['inverterEfficiencyEntityId'] as String?,
      weatherEntityId: json['weatherEntityId'] as String?,
      lastCleaningDate: DateTime.tryParse(json['lastCleaningDate'] as String? ?? ''),
      nextCleaningDate: DateTime.tryParse(json['nextCleaningDate'] as String? ?? ''),
      forecastDayEntityIds: rawForecast ?? const [null, null, null, null, null, null, null],
    );
  }
}

/// Persists [EnergyPageConfig] via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same settings.
/// The settings card builds its own mutable draft rather than round-tripping
/// through a `copyWith` on this class: several fields here are nullable
/// non-`String` types (`double?`, `DateTime?`) where `existing ?? this.existing`-
/// style `copyWith` can never actually clear a field back to null, only ever
/// replace or leave it — the same trap `EnergyEntitiesCard`'s sensor rows
/// sidestep with their own plain mutable `_SensorDraftEntry`.
class EnergyPageSettingsStore {
  EnergyPageSettingsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'energy_page_settings';

  Future<EnergyPageConfig> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! Map) return const EnergyPageConfig();
    return EnergyPageConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> save(EnergyPageConfig config) async {
    await _client.setSettings(_key, blankStringsToNull(config.toJson()));
  }
}
