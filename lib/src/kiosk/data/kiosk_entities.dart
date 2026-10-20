import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/energy_entities_provider.dart';
import '../../providers/ev_cars_provider.dart';
import '../../providers/ha_providers.dart';
import '../../providers/individual_sensors_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../providers/temperature_entities_provider.dart';
import '../../utils/optimistic.dart';
import 'house_config.dart';

/// Domains the kiosk screens read wholesale. Plain `sensor.*` is not one of
/// them — a large instance has over a thousand, updating constantly — so
/// sensors only count when some config names them (see [_configuredIds]).
const _domains = {
  'light',
  'climate',
  'lock',
  'cover',
  'alarm_control_panel',
  'scene',
  'script',
  'person',
  'todo',
  'calendar',
  'weather',
  'water_heater',
  'camera',
};

const _binaryClasses = {'door', 'window', 'opening', 'garage_door', 'motion', 'occupancy', 'presence', 'smoke', 'moisture', 'gas', 'carbon_monoxide'};

/// Every entity id any kiosk config points at.
final _configuredIds = Provider<Set<String>>((ref) {
  final ids = <String?>{};
  final energy = ref.watch(energyEntityConfigProvider);
  ids.addAll([energy.gridPowerEntityId, energy.solarPowerEntityId, energy.batteryPowerEntityId, energy.batterySocEntityId, energy.homePowerEntityId]);
  for (final s in ref.watch(individualSensorsProvider)) {
    ids.addAll([s.powerEntityId, s.temperatureEntityId]);
  }
  final ev = ref.watch(evCarsConfigProvider);
  for (final c in [ev.left, ev.right]) {
    ids.addAll([c.batterySocEntityId, c.rangeEntityId, c.chargingEntityId, c.plugConnectedEntityId, c.chargeLimitEntityId, c.chargePowerEntityId]);
  }
  final t = ref.watch(temperatureEntityConfigProvider);
  ids.addAll([t.exteriorTempEntityId, t.weatherStateEntityId]);
  for (final a in ref.watch(areasProvider)) {
    ids.addAll([a.temperatureEntityId, a.humidityEntityId]);
  }
  for (final r in ref.watch(roomsProvider)) {
    ids.addAll([r.secondaryEntityId, r.lightEntityId, r.windowEntityId, r.climateEntityId, r.coverEntityId]);
  }
  final house = ref.watch(houseConfigProvider);
  ids.addAll([house.alarmEntityId, house.waterHeaterEntityId, house.waterHeaterPowerEntityId, house.waterHeaterTempEntityId]);
  for (final e in [...house.scenes, ...house.locks, ...house.cameras]) {
    ids.add(e.entityId);
  }
  return {
    for (final id in ids)
      if (id != null && id.isNotEmpty) id,
  };
});

bool _relevant(HaEntity e, Set<String> configured) {
  if (configured.contains(e.entityId)) return true;
  final d = e.domain;
  if (_domains.contains(d)) return true;
  return d == 'binary_sensor' && _binaryClasses.contains(e.deviceClass);
}

/// The subset of [entitiesProvider] the kiosk screens draw from, which only
/// emits a new map when one of *those* entities changed — so a busy
/// instance's unrelated sensor chatter doesn't rebuild every screen five
/// times a second.
///
/// It also carries the screen's optimistic changes ([run]): a tapped light
/// shows on at once, and goes back if HA doesn't confirm it.
class KioskEntitiesNotifier extends Notifier<Map<String, HaEntity>> {
  Map<String, HaEntity> _real = const {};

  late final _optimistic = OptimisticLayer<HaEntity>(
    real: (id) => _real[id],
    onChanged: _publish,
    notConfirmed: 'O Home Assistant não confirmou a alteração',
  );

  @override
  Map<String, HaEntity> build() {
    final configured = ref.watch(_configuredIds);
    ref.listen<AsyncValue<Map<String, HaEntity>>>(entitiesProvider, (_, next) {
      final all = next.valueOrNull;
      if (all == null) return;
      _real = _filter(all, configured);
      _optimistic.settle();
      _publish();
    });
    _real = _filter(ref.read(entitiesProvider).valueOrNull ?? const {}, configured);
    return _optimistic.overlay(_real);
  }

  void _publish() {
    final shown = _optimistic.overlay(_real);
    if (_changed(state, shown)) state = shown;
  }

  /// Shows [changes] straight away while [call] (the service call) runs;
  /// see [OptimisticLayer.run].
  Future<void> run(List<OptimisticChange<HaEntity>> changes, Future<void> Function() call, {Duration timeout = OptimisticLayer.defaultTimeout}) =>
      _optimistic.run(changes, call, timeout: timeout);

  static Map<String, HaEntity> _filter(Map<String, HaEntity> all, Set<String> configured) => {
    for (final e in all.values)
      if (_relevant(e, configured)) e.entityId: e,
  };

  static bool _changed(Map<String, HaEntity> a, Map<String, HaEntity> b) {
    if (a.length != b.length) return true;
    for (final e in b.entries) {
      if (!identical(a[e.key], e.value)) return true;
    }
    return false;
  }
}

final kioskEntitiesProvider = NotifierProvider<KioskEntitiesNotifier, Map<String, HaEntity>>(KioskEntitiesNotifier.new);

double? numState(HaEntity? e) {
  if (e == null || e.isUnavailable) return null;
  return double.tryParse(e.state);
}

double? numAttr(HaEntity? e, String key) {
  final v = e?.attributes[key];
  return v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
}

bool truthy(HaEntity? e) {
  final s = e?.state.toLowerCase();
  return s == 'on' || s == 'true' || s == 'charging' || s == 'connected' || s == 'plugged_in' || s == 'plugged' || s == 'home' || s == 'open';
}
