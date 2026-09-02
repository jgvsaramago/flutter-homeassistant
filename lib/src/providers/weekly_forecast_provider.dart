import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'temperature_entities_provider.dart';

/// One day of the Homepage's 7-day forecast card — [condition] is the raw
/// HA weather condition string (`sunny`, `partlycloudy`, `rainy`, ...); the
/// card itself maps that to an icon/colour, this provider only fetches and
/// parses. [condition]/[high]/[low] are all null when this day has no data
/// — the weather entity is unconfigured/unavailable, or the integration
/// returned fewer than 7 days — so the card still renders 7 columns with
/// "--", the same convention every other unconfigured metric in this app
/// already uses.
class WeeklyForecastDay {
  const WeeklyForecastDay({required this.label, required this.condition, required this.high, required this.low});

  final String label;
  final String? condition;
  final int? high;
  final int? low;

  factory WeeklyForecastDay.empty(String label) => WeeklyForecastDay(label: label, condition: null, high: null, low: null);
}

const _weekdayAbbrevPt = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _dayCount = 7;

String _labelFor(int index, DateTime date) => index == 0 ? 'Hoje' : _weekdayAbbrevPt[date.weekday - 1];

/// Fetches (and periodically refreshes) the Temperaturas settings' own
/// weather entity's daily forecast via HA's `weather.get_forecasts`
/// service. Always resolves to exactly 7 entries, today first, so the card
/// never has to special-case a short or missing response.
class WeeklyForecastNotifier extends AsyncNotifier<List<WeeklyForecastDay>> {
  Timer? _refreshTimer;

  static const _refreshInterval = Duration(minutes: 30);

  @override
  Future<List<WeeklyForecastDay>> build() async {
    final entityId = ref.watch(temperatureEntityConfigProvider.select((c) => c.weatherStateEntityId));

    ref.onDispose(() => _refreshTimer?.cancel());

    final today = DateTime.now();
    final labels = [for (var i = 0; i < _dayCount; i++) _labelFor(i, today.add(Duration(days: i)))];

    if (entityId == null || entityId.trim().isEmpty) {
      return [for (final label in labels) WeeklyForecastDay.empty(label)];
    }

    // Waits for a live connection first, same idiom as the rest of this
    // app's HA-backed providers (`areaByEntityIdProvider`, etc.).
    await ref.watch(entitiesProvider.future);
    final client = ref.read(haWebSocketClientProvider);

    // A self-rescheduling one-shot timer rather than `Timer.periodic`: each
    // rebuild's `onDispose` above cancels exactly the timer *that* build
    // registered, so there's never more than one in flight even across
    // reconnects/entity-id changes.
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshInterval, ref.invalidateSelf);

    // A failed fetch (offline, integration doesn't support the service,
    // ...) falls back to the same "--" placeholder days as an unconfigured
    // entity, rather than an `AsyncError` that would leave the card with
    // zero columns instead of its usual 7 — the retry timer above still
    // fires either way.
    List<Map<String, dynamic>> forecast;
    try {
      forecast = await client.getWeatherForecasts(entityId);
    } catch (_) {
      forecast = const [];
    }

    return [
      for (var i = 0; i < _dayCount; i++)
        i < forecast.length ? _parseDay(labels[i], forecast[i]) : WeeklyForecastDay.empty(labels[i]),
    ];
  }

  WeeklyForecastDay _parseDay(String label, Map<String, dynamic> entry) {
    final high = entry['temperature'];
    final low = entry['templow'];
    return WeeklyForecastDay(
      label: label,
      condition: entry['condition'] as String?,
      high: high is num ? high.round() : null,
      low: low is num ? low.round() : null,
    );
  }
}

final weeklyForecastProvider = AsyncNotifierProvider<WeeklyForecastNotifier, List<WeeklyForecastDay>>(WeeklyForecastNotifier.new);
