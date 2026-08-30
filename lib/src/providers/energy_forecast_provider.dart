import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ha_entity.dart';
import 'energy_page_settings_provider.dart';
import 'ha_providers.dart';

enum SolarCondition { sun, partly, rain }

class ForecastDay {
  const ForecastDay({required this.date, required this.label, required this.kwh, required this.condition, required this.tempMax});

  final DateTime date;
  final String label;

  /// Null when this day's entity isn't configured or is unavailable — the
  /// row still renders (with "--") rather than disappearing, so the 7-day
  /// list always shows 7 rows.
  final double? kwh;
  final SolarCondition condition;
  final int? tempMax;
}

class EnergyForecastData {
  const EnergyForecastData({required this.days, required this.hourlyExpectedKwh, required this.hasHourlyForecast});

  /// Always 7 entries, today first.
  final List<ForecastDay> days;

  /// 24 entries, today's expected production per hour — from the "today"
  /// Solcast entity's `detailedForecast` attribute, resampled from its
  /// native half-hourly periods. All zero (with [hasHourlyForecast] false)
  /// when that attribute isn't present.
  final List<double> hourlyExpectedKwh;
  final bool hasHourlyForecast;

  double? get todayTotalKwh => days.isEmpty ? null : days.first.kwh;

  double? get sevenDayTotalKwh {
    if (days.every((d) => d.kwh == null)) return null;
    return days.fold<double>(0.0, (sum, d) => sum + (d.kwh ?? 0));
  }

  static const empty = EnergyForecastData(days: [], hourlyExpectedKwh: [], hasHourlyForecast: false);
}

const _weekdayAbbrevPt = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Derives the 7-day solar forecast and today's hourly "previsto" bars from
/// whatever Solcast (or similar) day entities and optional weather entity
/// are configured — purely from already-live entity state/attributes, so
/// this is a plain synchronous `Provider`, not a fetch.
final energyForecastProvider = Provider<EnergyForecastData>((ref) {
  final config = ref.watch(energyPageConfigProvider);
  final entityMap = ref.watch(entitiesProvider.select((async) => async.value ?? const {}));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weatherByDate = _parseWeatherForecast(entityMap, config.weatherEntityId);

  final days = <ForecastDay>[];
  for (var i = 0; i < 7; i++) {
    final date = today.add(Duration(days: i));
    final entityId = config.forecastDayEntityIds[i];
    final entity = entityId == null || entityId.trim().isEmpty ? null : entityMap[entityId];
    final kwh = (entity == null || entity.isUnavailable) ? null : double.tryParse(entity.state);
    final weather = weatherByDate[_dateKey(date)];
    days.add(
      ForecastDay(
        date: date,
        label: i == 0 ? 'Hoje' : _weekdayAbbrevPt[date.weekday - 1],
        kwh: kwh,
        condition: weather?.condition ?? SolarCondition.partly,
        tempMax: weather?.tempMax,
      ),
    );
  }

  final todayEntityId = config.forecastDayEntityIds[0];
  final todayEntity = todayEntityId == null || todayEntityId.trim().isEmpty ? null : entityMap[todayEntityId];
  final hourly = _parseDetailedForecast(todayEntity, today);

  return EnergyForecastData(days: days, hourlyExpectedKwh: hourly ?? List.filled(24, 0), hasHourlyForecast: hourly != null);
});

String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

class _WeatherDay {
  const _WeatherDay(this.condition, this.tempMax);
  final SolarCondition condition;
  final int? tempMax;
}

/// Reads the legacy `forecast` attribute some `weather.*` entities still
/// expose (a list of `{datetime, condition, temperature}` maps) — modern HA
/// moved daily forecasts behind a service call this app's plain
/// `get_states`/`state_changed` plumbing doesn't reach, so this only ever
/// populates for integrations/versions that still attach it directly to the
/// entity. Absent or malformed data just leaves every day on the generic
/// "partly cloudy, no temperature" fallback.
Map<String, _WeatherDay> _parseWeatherForecast(Map<String, HaEntity> entities, String? weatherEntityId) {
  if (weatherEntityId == null || weatherEntityId.trim().isEmpty) return const {};
  final entity = entities[weatherEntityId];
  if (entity == null) return const {};
  final forecast = entity.attributes['forecast'];
  if (forecast is! List) return const {};

  final result = <String, _WeatherDay>{};
  for (final entry in forecast) {
    if (entry is! Map) continue;
    final datetimeRaw = entry['datetime'];
    final dt = datetimeRaw is String ? DateTime.tryParse(datetimeRaw) : null;
    if (dt == null) continue;
    final local = dt.toLocal();
    final conditionRaw = (entry['condition'] as String?)?.toLowerCase() ?? '';
    final condition = _conditionFor(conditionRaw);
    final temp = entry['temperature'];
    final tempMax = temp is num ? temp.round() : null;
    result[_dateKey(local)] = _WeatherDay(condition, tempMax);
  }
  return result;
}

SolarCondition _conditionFor(String haCondition) {
  if (haCondition.contains('rain') || haCondition.contains('snow') || haCondition.contains('storm') || haCondition.contains('hail')) {
    return SolarCondition.rain;
  }
  if (haCondition.contains('cloud') || haCondition.contains('fog')) return SolarCondition.partly;
  return SolarCondition.sun;
}

/// Resamples Solcast's `detailedForecast` attribute (half-hourly
/// `{period_start, pv_estimate}` entries, `pv_estimate` in kWh for that
/// period) into 24 hourly buckets for [day]. Returns null when the
/// attribute is missing or empty, so callers can tell "no forecast
/// configured" apart from "forecast is genuinely all zero".
List<double>? _parseDetailedForecast(HaEntity? entity, DateTime day) {
  if (entity == null) return null;
  final raw = entity.attributes['detailedForecast'] ?? entity.attributes['detailed_forecast'];
  if (raw is! List || raw.isEmpty) return null;

  final hours = List<double>.filled(24, 0);
  var found = false;
  for (final entry in raw) {
    if (entry is! Map) continue;
    final startRaw = entry['period_start'] ?? entry['period_end'];
    final start = startRaw is String ? DateTime.tryParse(startRaw) : null;
    if (start == null) continue;
    final local = start.toLocal();
    if (local.year != day.year || local.month != day.month || local.day != day.day) continue;
    final estimate = entry['pv_estimate'];
    if (estimate is! num) continue;
    hours[local.hour] += estimate.toDouble();
    found = true;
  }
  return found ? hours : null;
}
