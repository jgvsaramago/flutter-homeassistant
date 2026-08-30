import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ha_client/ha_websocket_client.dart';
import '../models/ha_entity.dart';
import '../models/ha_history_point.dart';
import 'energy_entities_provider.dart';
import 'ha_providers.dart';

/// One hour (00-23) of today's real energy flow, in kWh — derived from the
/// same grid/solar/battery/home power entities the compact flow card reads
/// live, but integrated over HA's recorder history instead of read
/// instantaneously. Mirrors the reference design's per-hour derivation
/// (`solarToHouse = min(solar, load)`, `gridToHouse = max(0, load -
/// solarToHouse - fromBattery)`) with hourly kWh in place of the mock's
/// instantaneous kW scalars.
class EnergyHourlyBucket {
  const EnergyHourlyBucket({
    required this.hour,
    required this.solarKwh,
    required this.solarToHouseKwh,
    required this.fromBatteryKwh,
    required this.toBatteryKwh,
    required this.gridToHouseKwh,
    required this.injectedKwh,
    required this.isFuture,
  });

  final int hour;

  /// Total solar production this hour — feeds the production chart's
  /// "actual" bar independent of where it went.
  final double solarKwh;
  final double solarToHouseKwh;
  final double fromBatteryKwh;
  final double toBatteryKwh;
  final double gridToHouseKwh;

  /// Solar surplus not self-consumed or sent to the battery — derived
  /// (`solar - solarToHouse - toBattery`), not read off a separate grid
  /// export sensor: without a dedicated export meter this is the only way
  /// to get a figure that never disagrees with the produced/consumed totals
  /// shown next to it.
  final double injectedKwh;

  /// True once [hour] is later than the current hour — no history exists
  /// yet, so this hour's bars render empty rather than a fabricated guess.
  final bool isFuture;

  double get houseLoadKwh => solarToHouseKwh + fromBatteryKwh + gridToHouseKwh;

  /// An empty bucket for [hour] — the chart fallback while nothing is
  /// configured/loaded yet, so it always has 24 buckets to lay out rather
  /// than special-casing "no data".
  factory EnergyHourlyBucket.zero(int hour) => EnergyHourlyBucket(
    hour: hour,
    solarKwh: 0,
    solarToHouseKwh: 0,
    fromBatteryKwh: 0,
    toBatteryKwh: 0,
    gridToHouseKwh: 0,
    injectedKwh: 0,
    isFuture: false,
  );
}

class EnergyHistoryData {
  const EnergyHistoryData({
    required this.hours,
    required this.hasSolar,
    required this.hasBattery,
    required this.hasHome,
    required this.peakSolarKw,
    required this.peakSolarTime,
  });

  /// Always 24 entries, hour 0..23.
  final List<EnergyHourlyBucket> hours;

  /// Whether each source has an entity configured at all — distinguishes
  /// "not configured" (show "--") from "configured and genuinely zero"
  /// (e.g. solar overnight).
  final bool hasSolar;
  final bool hasBattery;
  final bool hasHome;

  final double? peakSolarKw;
  final DateTime? peakSolarTime;

  double get producedTodayKwh => hours.fold(0, (sum, h) => sum + h.solarKwh);
  double get consumedTodayKwh => hours.fold(0, (sum, h) => sum + h.houseLoadKwh);
  double get gridImportTodayKwh => hours.fold(0, (sum, h) => sum + h.gridToHouseKwh);
  double get injectedTodayKwh => hours.fold(0, (sum, h) => sum + h.injectedKwh);
  double get batteryChargedTodayKwh => hours.fold(0, (sum, h) => sum + h.toBatteryKwh);

  static const empty = EnergyHistoryData(
    hours: [],
    hasSolar: false,
    hasBattery: false,
    hasHome: false,
    peakSolarKw: null,
    peakSolarTime: null,
  );
}

/// Splits a signed power series into per-hour positive/negative kWh —
/// [points] are HA's last-changed samples, which hold their value until the
/// next sample (a step function, not something to interpolate between), so
/// each inter-sample segment is split at hour boundaries and its constant
/// power multiplied by the slice of an hour it actually spans. Splitting
/// per segment (not per hourly net) preserves a sign flip that happens
/// mid-hour, e.g. the battery finishing a charge and starting to discharge
/// within the same hour.
class _HourlySplit {
  _HourlySplit(List<HaHistoryPoint> points, double unitScale, DateTime dayStart, DateTime clampEnd)
    : positive = List<double>.filled(24, 0),
      negative = List<double>.filled(24, 0) {
    if (points.isEmpty) return;
    final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
    for (var i = 0; i < sorted.length; i++) {
      final segStart = sorted[i].time;
      if (!segStart.isBefore(clampEnd)) continue;
      final segEndRaw = i + 1 < sorted.length ? sorted[i + 1].time : clampEnd;
      final segEnd = segEndRaw.isAfter(clampEnd) ? clampEnd : segEndRaw;
      if (!segEnd.isAfter(segStart)) continue;
      final kw = sorted[i].value * unitScale;
      var cursor = segStart;
      while (cursor.isBefore(segEnd)) {
        final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
        final pieceEnd = hourEnd.isBefore(segEnd) ? hourEnd : segEnd;
        final hoursFraction = pieceEnd.difference(cursor).inMilliseconds / 3600000.0;
        final kwh = kw * hoursFraction;
        final hourIndex = cursor.difference(dayStart).inHours;
        if (hourIndex >= 0 && hourIndex < 24) {
          if (kwh >= 0) {
            positive[hourIndex] += kwh;
          } else {
            negative[hourIndex] += -kwh;
          }
        }
        cursor = pieceEnd;
      }
    }
  }

  final List<double> positive;
  final List<double> negative;
}

/// Auto-refreshing HA history for the Energia page's hourly charts and KPI
/// totals — `autoDispose` so this stops polling the moment the Energia tab
/// isn't on screen (this app swaps tabs by fully unmounting the old one, not
/// `IndexedStack`, so losing all watchers here really does mean off-screen).
class EnergyHistoryNotifier extends AutoDisposeAsyncNotifier<EnergyHistoryData> {
  static const _refreshInterval = Duration(minutes: 5);
  Timer? _refreshTimer;

  @override
  Future<EnergyHistoryData> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());
    _refreshTimer ??= Timer.periodic(_refreshInterval, (_) => ref.invalidateSelf());

    final config = ref.watch(energyEntityConfigProvider);
    final entities = ref.read(entitiesProvider).value ?? const {};
    final client = ref.read(haWebSocketClientProvider);

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final currentHour = now.hour;

    final solarPoints = await _history(client, config.solarPowerEntityId, dayStart, now);
    final batteryPoints = await _history(client, config.batteryPowerEntityId, dayStart, now);
    final homePoints = await _history(client, config.homePowerEntityId, dayStart, now);

    final solarScale = _unitScale(entities, config.solarPowerEntityId);
    final batteryScale = _unitScale(entities, config.batteryPowerEntityId);
    final homeScale = _unitScale(entities, config.homePowerEntityId);

    final solarSplit = _HourlySplit(solarPoints, solarScale, dayStart, now);
    final batterySplit = _HourlySplit(batteryPoints, batteryScale, dayStart, now);
    final homeSplit = _HourlySplit(homePoints, homeScale, dayStart, now);

    final hours = [
      for (var h = 0; h < 24; h++)
        _bucket(
          hour: h,
          isFuture: h > currentHour,
          solarKwh: solarSplit.positive[h],
          homeKwh: homeSplit.positive[h],
          fromBatteryKwh: batterySplit.positive[h],
          toBatteryKwh: batterySplit.negative[h],
        ),
    ];

    double? peakKw;
    DateTime? peakTime;
    for (final p in solarPoints) {
      final kw = p.value * solarScale;
      if (peakKw == null || kw > peakKw) {
        peakKw = kw;
        peakTime = p.time;
      }
    }

    return EnergyHistoryData(
      hours: hours,
      hasSolar: _hasEntity(config.solarPowerEntityId),
      hasBattery: _hasEntity(config.batteryPowerEntityId),
      hasHome: _hasEntity(config.homePowerEntityId),
      peakSolarKw: peakKw,
      peakSolarTime: peakTime,
    );
  }

  EnergyHourlyBucket _bucket({
    required int hour,
    required bool isFuture,
    required double solarKwh,
    required double homeKwh,
    required double fromBatteryKwh,
    required double toBatteryKwh,
  }) {
    final solarToHouse = solarKwh < homeKwh ? solarKwh : homeKwh;
    final gridToHouse = (homeKwh - solarToHouse - fromBatteryKwh).clamp(0.0, double.infinity);
    final injected = (solarKwh - solarToHouse - toBatteryKwh).clamp(0.0, double.infinity);
    return EnergyHourlyBucket(
      hour: hour,
      solarKwh: solarKwh,
      solarToHouseKwh: solarToHouse,
      fromBatteryKwh: fromBatteryKwh,
      toBatteryKwh: toBatteryKwh,
      gridToHouseKwh: gridToHouse,
      injectedKwh: injected,
      isFuture: isFuture,
    );
  }

  bool _hasEntity(String? id) => id != null && id.trim().isNotEmpty;

  Future<List<HaHistoryPoint>> _history(HaWebSocketClient client, String? entityId, DateTime start, DateTime end) async {
    if (!_hasEntity(entityId)) return const [];
    try {
      return await client.historyDuringPeriod(entityId!, start: start, end: end);
    } catch (_) {
      // A slow/unavailable recorder shouldn't blank out the rest of the
      // page — this source's hours just read as zero, same as unconfigured.
      return const [];
    }
  }

  /// History points carry no `unit_of_measurement` (`no_attributes: true`
  /// keeps the request cheap) — read it off the entity's current live state
  /// instead, same "kW unless stated otherwise" default `_readPowerKw` uses
  /// on the flow card, on the assumption a sensor's unit doesn't change
  /// mid-day.
  double _unitScale(Map<String, HaEntity> entities, String? entityId) {
    if (entityId == null) return 0.001;
    final unit = entities[entityId]?.unitOfMeasurement?.toLowerCase();
    return unit == 'kw' ? 1.0 : 0.001;
  }
}

final energyHistoryProvider = AutoDisposeAsyncNotifierProvider<EnergyHistoryNotifier, EnergyHistoryData>(
  EnergyHistoryNotifier.new,
);
