import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../providers/temperature_entities_provider.dart';
import '../../providers/weekly_forecast_provider.dart';
import 'house_models.dart';
import 'kiosk_entities.dart';
import 'pt_dates.dart';

/// "hoje às 08:31", "ontem às 19:40", "sáb às 10:00", "12 out às 10:00".
String ptWhen(DateTime t) {
  final now = DateTime.now();
  final days = daysBetween(t, now);
  final at = 'às ${PtDates.hm(t)}';
  if (days == 0) return 'hoje $at';
  if (days == 1) return 'ontem $at';
  if (days < 7) return '${PtDates.abbrLower[t.weekday - 1]} $at';
  return '${PtDates.short(t)} $at';
}

/// "1,4 kW", "0,15 kW", "12 kW".
String ptKw(double v) {
  final a = v.abs();
  final s = ptDec(a, decimals: a < 1 ? 2 : (a < 10 ? 1 : 0));
  return '${s.contains(',') ? s.replaceAll(RegExp(r',?0+$'), '') : s} kW';
}

/// kWh with one decimal ("0,6", "14,2").
String ptKwh(double v) => ptDec(v, decimals: 1);

// ─── Weather station ───────────────────────────────────────────────────

/// What the exterior station's other sensors are: found on the same HA
/// device as the exterior temperature sensor chosen in the panel
/// (Meteorologia), by device class and name — a weather station
/// integration (Ecowitt, Netatmo, …) puts them all on one device.
enum StationRole { feels, dewPoint, humidity, wind, gust, gustMax, windDir, rain, rainRate, pressure, uv, irradiance }

StationRole? _roleOf(HaEntity e) {
  final dc = e.deviceClass;
  final n = '${e.entityId} ${e.friendlyName}'.toLowerCase();
  bool has(String re) => RegExp(re).hasMatch(n);
  if (e.domain != 'sensor') return null;
  if (dc == 'temperature') {
    if (has('feel|sensa|apparent')) return StationRole.feels;
    if (has('dew|orvalho')) return StationRole.dewPoint;
    return null;
  }
  if (dc == 'humidity') return has('indoor|interior|inside') ? null : StationRole.humidity;
  if (dc == 'wind_speed' || (has('wind|vento') && e.unitOfMeasurement == 'km/h')) {
    if (has('max|máx')) return StationRole.gustMax;
    if (has('gust|rajada')) return StationRole.gust;
    return StationRole.wind;
  }
  if (dc == 'wind_direction' || (has('wind|vento') && has('direc'))) return has('avg|média|media') ? null : StationRole.windDir;
  if (dc == 'precipitation_intensity' || has('rain_rate|rain rate')) return StationRole.rainRate;
  if (dc == 'precipitation' && has('daily|diári|diari|today|hoje')) return StationRole.rain;
  if (dc == 'atmospheric_pressure' || (dc == 'pressure' && e.unitOfMeasurement == 'hPa')) return has('absolute|absoluta') ? null : StationRole.pressure;
  if (has(r'\buv|uv_index|uv index|índice uv')) return StationRole.uv;
  if (dc == 'irradiance' || has('radia|irradi')) return StationRole.irradiance;
  return null;
}

/// The station's sensors by role (empty without a station).
final weatherStationProvider = FutureProvider<Map<StationRole, String>>((ref) async {
  final tempId = ref.watch(temperatureEntityConfigProvider.select((c) => c.exteriorTempEntityId));
  if (tempId == null || tempId.isEmpty) return const {};
  await haReady(ref);
  final devices = await ref.read(haWebSocketClientProvider).entityDeviceIds();
  final device = devices[tempId];
  if (device == null) return const {};
  final all = ref.read(entitiesProvider).valueOrNull ?? const <String, HaEntity>{};
  final out = <StationRole, String>{};
  for (final MapEntry(key: id, value: d) in devices.entries) {
    if (d != device || id == tempId) continue;
    final e = all[id];
    if (e == null) continue;
    final role = _roleOf(e);
    if (role != null) out.putIfAbsent(role, () => id);
  }
  return out;
});

/// How [ids] moved over their window (value now minus value then), for
/// the Exterior card's "a subir" lines. Refreshed every 10 minutes.
class _TrendsNotifier extends AsyncNotifier<Map<String, double>> {
  Timer? _timer;

  @override
  Future<Map<String, double>> build() async {
    final station = ref.watch(weatherStationProvider).valueOrNull ?? const {};
    final temp = ref.watch(temperatureEntityConfigProvider.select((c) => c.exteriorTempEntityId));
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 10), ref.invalidateSelf);
    await haReady(ref);
    final client = ref.read(haWebSocketClientProvider);
    final windows = <String, Duration>{
      if (temp != null && temp.isNotEmpty) temp: const Duration(hours: 1),
      // Not `?key: value`: null-aware map entries crash the release
      // compiler's constant evaluator (Flutter 3.44).
      if (station[StationRole.pressure] case final id?) id: const Duration(hours: 3),
      if (station[StationRole.irradiance] case final id?) id: const Duration(minutes: 30),
    };
    final out = <String, double>{};
    for (final MapEntry(key: id, value: window) in windows.entries) {
      try {
        final points = await client.historyDuringPeriod(id, start: DateTime.now().subtract(window));
        if (points.length >= 2) out[id] = points.last.value - points.first.value;
      } catch (_) {
        // No trend for this one.
      }
    }
    return out;
  }
}

final _trendsProvider = AsyncNotifierProvider<_TrendsNotifier, Map<String, double>>(_TrendsNotifier.new);

class ExteriorTile {
  const ExteriorTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
    required this.icon,
    required this.color,
    this.rotation = 0,
  });

  final String label;
  final String value;
  final String unit;
  final String sub;
  final String icon;
  final int color;

  /// Degrees (the wind arrow).
  final double rotation;
}

class ExteriorInfo {
  const ExteriorInfo({
    required this.period,
    required this.temp,
    required this.feels,
    required this.max,
    required this.min,
    required this.trend,
    required this.trendDir,
    required this.tiles,
  });

  final String period;
  final double? temp;
  final double? feels;
  final int? max;
  final int? min;
  final String? trend;

  /// 1 up, -1 down, 0 steady.
  final int trendDir;
  final List<ExteriorTile> tiles;
}

const _compass = ['norte', 'nordeste', 'este', 'sudeste', 'sul', 'sudoeste', 'oeste', 'noroeste'];

String _uvLevel(double uv) => uv < 3
    ? 'Baixo'
    : uv < 6
    ? 'Moderado'
    : uv < 8
    ? 'Alto'
    : uv < 11
    ? 'Muito alto'
    : 'Extremo';

/// The Casa page's Exterior card: the weather station's readings, or
/// what the `weather.*` entity reports where there's no station sensor.
final exteriorProvider = Provider<ExteriorInfo>((ref) {
  final t = ref.watch(temperatureEntityConfigProvider);
  final station = ref.watch(weatherStationProvider).valueOrNull ?? const {};
  final entities = ref.watch(kioskEntitiesProvider);
  final trends = ref.watch(_trendsProvider).valueOrNull ?? const {};
  final days = ref.watch(weeklyForecastProvider).valueOrNull;
  final weather = entities[t.weatherStateEntityId ?? ''];
  final tempEntity = entities[t.exteriorTempEntityId ?? ''];
  double? st(StationRole r) => numState(entities[station[r] ?? '']);
  double? attr(String k) => weather == null || weather.isUnavailable ? null : numAttr(weather, k);

  final now = DateTime.now();
  final temp = numState(tempEntity) ?? attr('temperature');
  final source = tempEntity != null && station.isNotEmpty
      ? () {
          final mins = now.difference(tempEntity.lastUpdated.toLocal()).inMinutes;
          return 'estação meteorológica, ${mins < 1 ? 'agora mesmo' : 'há $mins min'}';
        }()
      : weather?.friendlyName;
  final period = ['Hoje, ${PtDates.weekdays[now.weekday - 1]} ${now.day} de ${PtDates.months[now.month - 1]}', ?source].join(' · ');

  String? trend;
  var dir = 0;
  final dt = trends[t.exteriorTempEntityId];
  if (dt != null) {
    dir = dt > 0.3 ? 1 : (dt < -0.3 ? -1 : 0);
    trend = dir == 0 ? 'Estável na última hora' : '${dir > 0 ? 'A subir · +' : 'A descer · −'}${ptDec(dt.abs())}° na última hora';
  }

  final tiles = <ExteriorTile>[];
  final hum = st(StationRole.humidity) ?? attr('humidity');
  if (hum != null) {
    final dew = st(StationRole.dewPoint) ?? attr('dew_point');
    tiles.add(
      ExteriorTile(
        label: 'Humidade',
        value: '${hum.round()}',
        unit: '%',
        sub: dew == null ? '' : 'Ponto de orvalho ${dew.round()}°',
        icon: _drop,
        color: 0xFF1864AB,
      ),
    );
  }
  final wind = st(StationRole.wind) ?? attr('wind_speed');
  if (wind != null) {
    final from = st(StationRole.windDir) ?? attr('wind_bearing');
    final gust = st(StationRole.gustMax) ?? st(StationRole.gust) ?? attr('wind_gust_speed');
    tiles.add(
      ExteriorTile(
        label: 'Vento',
        value: '${wind.round()}',
        unit: 'km/h',
        sub: [if (from != null) 'De ${_compass[((from % 360) / 45).round() % 8]}', if (gust != null) 'rajada máx. ${gust.round()}'].join(' · '),
        icon: _arrowUp,
        color: 0xFF17191C,
        // HA gives where the wind comes from; the arrow points where it goes.
        rotation: from == null ? 0 : (from + 180) % 360,
      ),
    );
  }
  final rain = st(StationRole.rain) ?? attr('precipitation');
  if (rain != null) {
    final rate = st(StationRole.rainRate) ?? 0;
    tiles.add(
      ExteriorTile(
        label: 'Chuva',
        value: ptDec(rain),
        unit: 'mm',
        sub: rate > 0 ? 'A chover · ${ptDec(rate)} mm/h' : 'Acumulada hoje · sem chuva agora',
        icon: _rain,
        color: 0xFF1864AB,
      ),
    );
  }
  final pressure = st(StationRole.pressure) ?? attr('pressure');
  if (pressure != null) {
    final dp = trends[station[StationRole.pressure]];
    tiles.add(
      ExteriorTile(
        label: 'Pressão',
        value: '${pressure.round()}',
        unit: 'hPa',
        sub: dp == null ? '' : (dp > 1 ? 'A subir' : (dp < -1 ? 'A descer' : 'Estável')),
        icon: _gauge,
        color: 0xFF5F646B,
      ),
    );
  }
  final uv = st(StationRole.uv) ?? attr('uv_index');
  if (uv != null) {
    tiles.add(ExteriorTile(label: 'Índice UV', value: '${uv.round()}', unit: '', sub: '${_uvLevel(uv)} agora', icon: _sunSmall, color: 0xFFC98A2A));
  }
  final rad = st(StationRole.irradiance);
  if (rad != null) {
    final dr = trends[station[StationRole.irradiance]];
    tiles.add(
      ExteriorTile(
        label: 'Radiação solar',
        value: '${rad.round()}',
        unit: 'W/m²',
        sub: dr == null ? '' : (dr > 20 ? 'A aumentar' : (dr < -20 ? 'A diminuir' : 'Estável')),
        icon: _panel,
        color: 0xFFC98A2A,
      ),
    );
  }

  final today = days != null && days.isNotEmpty ? days.first : null;
  return ExteriorInfo(
    period: period,
    temp: temp,
    feels: st(StationRole.feels) ?? attr('apparent_temperature'),
    max: today?.high,
    min: today?.low,
    trend: trend,
    trendDir: dir,
    tiles: tiles,
  );
});

/// The weather station's sensor ids, so [kioskEntitiesProvider] keeps them.
final weatherStationIdsProvider = Provider<Set<String>>((ref) => {...?ref.watch(weatherStationProvider).valueOrNull?.values});

const _drop = '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>';
const _arrowUp = '<path d="M12 19V5M6 11l6-6 6 6"/>';
const _rain = '<path d="M7 14h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 5.1 4.5 4.5 0 0 0 7 14zM8 18l-1 3M12 18l-1 3M16 18l-1 3"/>';
const _gauge = '<path d="M4 18a8 8 0 1 1 16 0M12 18l4-6"/>';
const _sunSmall = '<path d="M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M2 12h2M20 12h2"/>';
const _panel = '<path d="M3 19l3-12h12l3 12zM4.5 13h15M9 7l-1 12M15 7l1 12"/>';

// ─── Doors and gates: when they were last opened ───────────────────────

/// When each configured lock or gate last went open (unlocked), from the
/// last week of HA history. Re-read whenever one of them changes state.
final lockLastOpenedProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final key = ref.watch(locksProvider.select((l) => [for (final x in l) '${x.entityId}:${x.secured}'].join(',')));
  final ids = [
    for (final part in key.split(','))
      if (part.isNotEmpty) part.substring(0, part.lastIndexOf(':')),
  ];
  if (ids.isEmpty) return const {};
  await haReady(ref);
  final history = await ref.read(haWebSocketClientProvider).stateHistory(ids, start: DateTime.now().subtract(const Duration(days: 7)));
  final out = <String, DateTime>{};
  for (final MapEntry(key: id, value: states) in history.entries) {
    for (final s in states) {
      if (s.state == 'unlocked' || s.state == 'open' || s.state == 'opening' || s.state == 'unlocking') out[id] = s.at;
    }
  }
  return out;
});

// ─── Energy: today's totals, the week, the solar forecast ──────────────

class _EnergyPrefs {
  _EnergyPrefs(Map<String, dynamic> json) {
    for (final s in (json['energy_sources'] as List? ?? const []).whereType<Map>()) {
      String? id(String k) => s[k] is String ? s[k] as String : null;
      switch (s['type']) {
        case 'solar':
          if (id('stat_energy_from') case final v?) solar.add(v);
        case 'battery':
          if (id('stat_energy_from') case final v?) batteryOut.add(v);
          if (id('stat_energy_to') case final v?) batteryIn.add(v);
          if (s['capacity'] is num) capacity = (s['capacity'] as num).toDouble();
        case 'grid':
          if (id('stat_energy_from') case final v?) gridIn.add(v);
          if (id('stat_energy_to') case final v?) gridOut.add(v);
          if (id('stat_cost') case final v?) costs.add(v);
          priceEntity ??= id('entity_energy_price');
          if (s['number_energy_price'] is num) price ??= (s['number_energy_price'] as num).toDouble();
          exportPriceEntity ??= id('entity_energy_price_export');
          if (s['number_energy_price_export'] is num) exportPrice ??= (s['number_energy_price_export'] as num).toDouble();
      }
    }
  }

  final solar = <String>[], batteryIn = <String>[], batteryOut = <String>[], gridIn = <String>[], gridOut = <String>[], costs = <String>[];
  double? capacity;
  String? priceEntity, exportPriceEntity;
  double? price, exportPrice;

  List<String> get energyIds => [...solar, ...batteryIn, ...batteryOut, ...gridIn, ...gridOut];
}

/// One period's energy, in kWh.
class EnergyAmounts {
  const EnergyAmounts({this.solar = 0, this.gridIn = 0, this.gridOut = 0, this.batteryIn = 0, this.batteryOut = 0, this.cost});

  final double solar, gridIn, gridOut, batteryIn, batteryOut;

  /// What the grid import cost, when HA tracks it.
  final double? cost;

  double get consumption => math.max(0, solar + gridIn + batteryOut - gridOut - batteryIn);

  /// The share of [consumption] that came from the sun or the battery.
  double? get selfUse => consumption <= 0.05 ? null : (1 - gridIn / consumption).clamp(0.0, 1.0);

  EnergyAmounts operator +(EnergyAmounts o) => EnergyAmounts(
    solar: solar + o.solar,
    gridIn: gridIn + o.gridIn,
    gridOut: gridOut + o.gridOut,
    batteryIn: batteryIn + o.batteryIn,
    batteryOut: batteryOut + o.batteryOut,
    cost: cost == null && o.cost == null ? null : (cost ?? 0) + (o.cost ?? 0),
  );
}

class EnergyStats {
  const EnergyStats({
    required this.today,
    required this.yesterdaySoFar,
    required this.hours,
    required this.week,
    required this.forecastSlots,
    required this.forecastByDay,
    required this.capacity,
    required this.price,
    required this.exportPrice,
    required this.updated,
  });

  final EnergyAmounts today;
  final EnergyAmounts? yesterdaySoFar;

  /// Today, hour by hour from midnight (the current hour so far last).
  final List<EnergyAmounts> hours;

  /// The last 7 days, oldest first, today last (so far).
  final List<({DateTime day, EnergyAmounts amounts})> week;

  /// Today's solar forecast as (slot start, average kW over the slot).
  final List<({DateTime at, double kw})> forecastSlots;
  final Map<String, double> forecastByDay;
  final double? capacity;

  /// €/kWh now, bought and sold.
  final double? price;
  final double? exportPrice;
  final DateTime updated;

  double? forecastFor(DateTime day) => forecastByDay[PtDates.key(day)];

  ({DateTime at, double kw})? get forecastPeak => forecastSlots.isEmpty ? null : forecastSlots.reduce((a, b) => b.kw > a.kw ? b : a);

  /// What [a] saved against buying everything from the grid, at today's
  /// prices.
  double? savings(EnergyAmounts a) => price == null ? null : (a.consumption - a.gridIn) * price! + a.gridOut * (exportPrice ?? 0);
}

/// Reads HA's Energy dashboard: its sources (energy/get_prefs), their
/// recorded statistics for today, yesterday and the week, and the solar
/// forecast it shows. Refreshed every 5 minutes. Null when the Energy
/// dashboard isn't set up.
class EnergyStatsNotifier extends AsyncNotifier<EnergyStats?> {
  Timer? _timer;

  @override
  Future<EnergyStats?> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 5), ref.invalidateSelf);
    await haReady(ref);
    final client = ref.read(haWebSocketClientProvider);
    final all = ref.read(entitiesProvider).valueOrNull ?? const <String, HaEntity>{};
    final prefs = _EnergyPrefs(((await client.command('energy/get_prefs')) as Map?)?.cast<String, dynamic>() ?? const {});
    if (prefs.energyIds.isEmpty) return null;
    // HA keeps a cost statistic per grid source with a price (`<id>_cost`).
    final costIds = prefs.costs.isNotEmpty
        ? prefs.costs
        : [
            for (final id in prefs.gridIn)
              if (all.containsKey('${id}_cost')) '${id}_cost',
          ];
    final ids = [...prefs.energyIds, ...costIds];

    Future<Map<String, List<Map>>> stats(DateTime start, DateTime? end, String period) async {
      final raw = await client.command('recorder/statistics_during_period', {
        'start_time': start.toUtc().toIso8601String(),
        'end_time': ?end?.toUtc().toIso8601String(),
        'statistic_ids': ids,
        'period': period,
        'types': ['change'],
        'units': {'energy': 'kWh'},
      });
      return {for (final e in ((raw as Map?) ?? const {}).entries) e.key as String: (e.value as List).whereType<Map>().toList()};
    }

    final now = DateTime.now();
    final today = dateOnly(now);
    final hourStart = DateTime(now.year, now.month, now.day, now.hour);
    final results = await Future.wait([
      stats(today, hourStart, 'hour'),
      stats(hourStart, null, '5minute'),
      stats(addDays(today, -1), now.subtract(const Duration(days: 1)), 'hour'),
      stats(addDays(today, -6), today, 'day'),
      client.command('energy/solar_forecast').then((v) => v, onError: (_) => null),
    ]);
    final hourly = results[0] as Map<String, List<Map>>;
    final current = results[1] as Map<String, List<Map>>;
    final yesterday = results[2] as Map<String, List<Map>>;
    final daily = results[3] as Map<String, List<Map>>;

    // Buckets (by start time) → amounts.
    Map<int, EnergyAmounts> bucket(Map<String, List<Map>> s, int Function(DateTime) keyOf) {
      final out = <int, EnergyAmounts>{};
      void add(List<String> group, EnergyAmounts Function(double) make) {
        for (final id in group) {
          for (final row in s[id] ?? const <Map>[]) {
            final start = row['start'], change = row['change'];
            if (start is! num || change is! num) continue;
            final k = keyOf(DateTime.fromMillisecondsSinceEpoch(start.toInt()));
            out[k] = (out[k] ?? const EnergyAmounts()) + make(change.toDouble());
          }
        }
      }

      add(prefs.solar, (v) => EnergyAmounts(solar: v));
      add(prefs.gridIn, (v) => EnergyAmounts(gridIn: v));
      add(prefs.gridOut, (v) => EnergyAmounts(gridOut: v));
      add(prefs.batteryIn, (v) => EnergyAmounts(batteryIn: v));
      add(prefs.batteryOut, (v) => EnergyAmounts(batteryOut: v));
      add(costIds, (v) => EnergyAmounts(cost: v));
      return out;
    }

    EnergyAmounts sum(Iterable<EnergyAmounts> xs) => xs.fold(const EnergyAmounts(), (a, b) => a + b);

    final byHour = bucket(hourly, (t) => t.hour);
    final thisHour = sum(bucket(current, (t) => t.minute).values);
    final hours = [for (var h = 0; h < now.hour; h++) byHour[h] ?? const EnergyAmounts(), thisHour];
    final todayTotal = sum(hours);
    final byDay = bucket(daily, (t) => daysBetween(t, today));
    final week = [for (var d = 6; d >= 1; d--) (day: addDays(today, -d), amounts: byDay[-d] ?? const EnergyAmounts()), (day: today, amounts: todayTotal)];

    // The forecast: per config entry, Wh per slot (30 min or an hour).
    final slots = <DateTime, double>{};
    if (results[4] case final Map fc) {
      for (final entry in fc.values.whereType<Map>()) {
        for (final e in ((entry['wh_hours'] as Map?) ?? const {}).entries) {
          final t = DateTime.tryParse(e.key as String)?.toLocal();
          if (t == null || e.value is! num) continue;
          slots[t] = (slots[t] ?? 0) + (e.value as num).toDouble();
        }
      }
    }
    final keys = slots.keys.toList()..sort();
    final step = keys.length > 1 ? keys[1].difference(keys[0]) : const Duration(hours: 1);
    final byDayFc = <String, double>{};
    for (final k in keys) {
      byDayFc.update(PtDates.key(k), (v) => v + slots[k]! / 1000, ifAbsent: () => slots[k]! / 1000);
    }
    final todaySlots = [
      for (final k in keys)
        if (sameDay(k, now)) (at: k, kw: slots[k]! / 1000 / (step.inMinutes / 60)),
    ];

    final kiosk = ref.read(kioskEntitiesProvider);
    double? priceOf(String? id) => numState(kiosk[id ?? ''] ?? all[id ?? '']);
    return EnergyStats(
      today: todayTotal,
      yesterdaySoFar: yesterday.isEmpty ? null : sum(bucket(yesterday, (t) => t.hour).values),
      hours: hours,
      week: week,
      forecastSlots: todaySlots,
      forecastByDay: byDayFc,
      capacity: prefs.capacity,
      price: priceOf(prefs.priceEntity) ?? prefs.price,
      exportPrice: priceOf(prefs.exportPriceEntity) ?? prefs.exportPrice,
      updated: now,
    );
  }
}

final energyStatsProvider = AsyncNotifierProvider<EnergyStatsNotifier, EnergyStats?>(EnergyStatsNotifier.new);

/// A utility-meter style tariff sensor (state "Vazio", "Cheias",
/// "Ponta"), if the house has one — looked for once.
final _tariffIdProvider = FutureProvider<String?>((ref) async {
  await haReady(ref);
  final all = ref.read(entitiesProvider).valueOrNull ?? const <String, HaEntity>{};
  for (final e in all.values) {
    if ((e.domain == 'sensor' || e.domain == 'select') && e.entityId.contains('tarif') && _isTariff(e.state)) return e.entityId;
  }
  return null;
});

bool _isTariff(String s) => RegExp(r'^(vazio|cheias|ponta|super ?vazio)$', caseSensitive: false).hasMatch(s);

/// HA's current tariff period, capitalised.
final tariffNowProvider = Provider<String?>((ref) {
  final id = ref.watch(_tariffIdProvider).valueOrNull;
  if (id == null) return null;
  final state = ref.watch(entitiesProvider.select((a) => a.valueOrNull?[id]?.state));
  return state == null || !_isTariff(state) ? null : PtDates.cap(state.toLowerCase());
});

/// "Agora a casa usa 1,4 kW, 86% do sol e da bateria · bateria a 62%,
/// dura até às 12:40".
String energySummary(EnergyInfo e, EnergyStats? stats) {
  final parts = <String>[];
  if (e.homeKw != null) {
    final grid = math.max(0.0, e.gridKw ?? 0);
    final own = e.homeKw! > 0.05 ? ((1 - grid / e.homeKw!).clamp(0.0, 1.0) * 100).round() : null;
    parts.add('Agora a casa usa ${ptKw(e.homeKw!)}${own == null ? '' : ', $own% do sol e da bateria'}');
  }
  if (e.soc != null) {
    final until = batteryLastsUntil(e, stats);
    parts.add('bateria a ${e.soc!.round()}%${until == null ? '' : ', dura até às ${PtDates.hm(until)}'}');
  }
  return PtDates.cap(parts.join(' · '));
}

/// At the current discharge, when the battery runs out (null while it
/// isn't discharging, or without its capacity).
DateTime? batteryLastsUntil(EnergyInfo e, EnergyStats? stats) {
  final kw = e.batteryKw, soc = e.soc, cap = stats?.capacity;
  if (kw == null || soc == null || cap == null || kw < 0.05) return null;
  final hours = soc / 100 * cap / kw;
  if (hours > 48) return null;
  return DateTime.now().add(Duration(minutes: (hours * 60).round()));
}

/// When the sun is forecast to cover the house again (and so charge the
/// battery), today.
DateTime? solarCoversHomeAt(EnergyInfo e, EnergyStats? stats) {
  final home = e.homeKw;
  if (home == null || stats == null) return null;
  final now = DateTime.now();
  for (final s in stats.forecastSlots) {
    if (s.at.isAfter(now) && s.kw > home) return s.at;
  }
  return null;
}
