import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/energy_entities_provider.dart';
import '../../providers/ev_cars_provider.dart';
import '../../providers/ev_cars_store.dart';
import '../../providers/ha_providers.dart';
import '../../providers/individual_sensors_provider.dart';
import '../../providers/individual_sensors_store.dart';
import '../../providers/rooms_provider.dart';
import '../../providers/temperature_entities_provider.dart';
import '../../utils/optimistic.dart';
import '../../utils/power_reading.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'house_config.dart';
import 'kiosk_entities.dart';

/// Calls a service on one entity, showing [expect] meanwhile (see
/// [KioskEntitiesNotifier.run]).
Future<void> _call(
  Ref ref,
  String domain,
  String service,
  String entityId, {
  Map<String, dynamic>? data,
  List<OptimisticChange<HaEntity>> expect = const [],
  Duration timeout = OptimisticLayer.defaultTimeout,
}) => ref
    .read(kioskEntitiesProvider.notifier)
    .run(
      expect,
      () => ref.read(haWebSocketClientProvider).callService(domain, service, target: {'entity_id': entityId}, serviceData: data),
      timeout: timeout,
    );

/// The change "[id] will be in [state] / have [attrs]", confirmed once HA
/// reports exactly that (or by [confirmed], when HA reports it differently).
OptimisticChange<HaEntity> expectEntity(String id, {String? state, Map<String, Object?> attrs = const {}, bool Function(HaEntity)? confirmed}) =>
    OptimisticChange(
      id,
      slot: [if (state != null) 'state', ...attrs.keys].join(','),
      patch: (e) => e.copyWith(state: state, attributes: attrs.isEmpty ? null : {...e.attributes, ...attrs}),
      confirmed: confirmed ?? (e) => (state == null || e.state == state) && attrs.entries.every((a) => _same(e.attributes[a.key], a.value)),
    );

bool _same(Object? a, Object? b) => a is num && b is num ? (a - b).abs() < 0.01 : a == b;

// ─── Air conditioning ──────────────────────────────────────────────────

enum AcMode {
  auto('Automático', KColors.purpleTint, KColors.purple),
  heat('Aquecer', KColors.orangeTint, KColors.orange),
  cool('Arrefecer', KColors.blueTint, KColors.blue),
  fan('Ventilar', KColors.greenTint, KColors.greenInk);

  const AcMode(this.label, this.tint, this.color);

  final String label;
  final Color tint;
  final Color color;
}

AcMode? _acModeOf(String hvac) => switch (hvac) {
  'heat' => AcMode.heat,
  'cool' => AcMode.cool,
  'fan_only' || 'dry' => AcMode.fan,
  'heat_cool' || 'auto' => AcMode.auto,
  _ => null,
};

class AcUnit {
  const AcUnit({
    required this.entityId,
    required this.name,
    required this.current,
    required this.target,
    required this.on,
    required this.mode,
    required this.modes,
    required this.hvacModes,
    required this.min,
    required this.max,
    required this.step,
  });

  final String entityId;
  final String name;
  final double? current;
  final double? target;
  final bool on;
  final AcMode mode;
  final List<AcMode> modes;
  final List<String> hvacModes;
  final double min;
  final double max;
  final double step;

  String get shortName => name.startsWith('Quarto ') ? name.replaceFirst('Quarto ', 'Q. ') : name;

  /// The HA `hvac_mode` that [m] means on this unit.
  String hvacFor(AcMode m) => switch (m) {
    AcMode.heat => 'heat',
    AcMode.cool => 'cool',
    AcMode.fan => hvacModes.contains('fan_only') ? 'fan_only' : 'dry',
    AcMode.auto => hvacModes.contains('heat_cool') ? 'heat_cool' : 'auto',
  };
}

AcUnit _acUnit(HaEntity e, String name) {
  final hvacModes = ((e.attributes['hvac_modes'] as List?) ?? const []).whereType<String>().toList();
  final modes = <AcMode>[];
  for (final m in AcMode.values) {
    final ok = switch (m) {
      AcMode.auto => hvacModes.contains('heat_cool') || hvacModes.contains('auto'),
      AcMode.heat => hvacModes.contains('heat'),
      AcMode.cool => hvacModes.contains('cool'),
      AcMode.fan => hvacModes.contains('fan_only') || hvacModes.contains('dry'),
    };
    if (ok) modes.add(m);
  }
  return AcUnit(
    entityId: e.entityId,
    name: name,
    current: numAttr(e, 'current_temperature'),
    target: numAttr(e, 'temperature'),
    on: e.state != 'off' && !e.isUnavailable,
    mode: _acModeOf(e.state) ?? AcMode.heat,
    modes: modes,
    hvacModes: hvacModes,
    min: numAttr(e, 'min_temp') ?? 16,
    max: numAttr(e, 'max_temp') ?? 30,
    step: numAttr(e, 'target_temp_step') ?? 0.5,
  );
}

String _stripAcPrefix(String n) => n.replaceFirst(RegExp(r'^(Ar Condicionado|AC|A/C)\s+', caseSensitive: false), '').trim();

/// Every AC unit: the Divisões rooms' own `climate.*` units (named after
/// their area), or — none mapped — every climate entity that can cool.
final acUnitsProvider = Provider<List<AcUnit>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final rooms = ref.watch(roomEntriesProvider);
  final units = <AcUnit>[];
  for (final r in rooms) {
    final id = r.config.climateEntityId;
    final e = id == null ? null : entities[id];
    if (e != null && e.domain == 'climate') units.add(_acUnit(e, r.name));
  }
  if (units.isNotEmpty) return units;
  for (final e in entities.values) {
    if (e.domain != 'climate' || e.isUnavailable) continue;
    final modes = (e.attributes['hvac_modes'] as List?) ?? const [];
    if (modes.contains('cool')) units.add(_acUnit(e, _stripAcPrefix(e.friendlyName)));
  }
  units.sort((a, b) => a.name.compareTo(b.name));
  return units;
});

class AcActions {
  AcActions(this._ref);

  final Ref _ref;

  Future<void> power(AcUnit u, bool on) => _call(
    _ref,
    'climate',
    on ? 'turn_on' : 'turn_off',
    u.entityId,
    // Turning on resumes whatever mode the unit had, which HA doesn't say
    // while it's off — show the season's likely one until it reports.
    expect: [expectEntity(u.entityId, state: on ? _likelyHvac(u) : 'off', confirmed: on ? (e) => e.state != 'off' && !e.isUnavailable : null)],
  );

  Future<void> target(AcUnit u, double t) {
    final v = t.clamp(u.min, u.max);
    return _call(
      _ref,
      'climate',
      'set_temperature',
      u.entityId,
      data: {'temperature': v},
      expect: [
        expectEntity(u.entityId, attrs: {'temperature': v}),
      ],
    );
  }

  Future<void> mode(AcUnit u, AcMode m) {
    final hvac = u.hvacFor(m);
    return _call(
      _ref,
      'climate',
      'set_hvac_mode',
      u.entityId,
      data: {'hvac_mode': hvac},
      expect: [expectEntity(u.entityId, state: hvac)],
    );
  }

  Future<void> allOff(List<AcUnit> units) => Future.wait([for (final u in units.where((u) => u.on)) power(u, false)]);

  Future<void> allOn(List<AcUnit> units) => Future.wait([for (final u in units.where((u) => !u.on)) power(u, true)]);
}

final acActionsProvider = Provider<AcActions>((ref) => AcActions(ref));

String _likelyHvac(AcUnit u) {
  final month = DateTime.now().month;
  final want = month >= 5 && month <= 9 ? 'cool' : 'heat';
  if (u.hvacModes.contains(want)) return want;
  return u.hvacModes.firstWhere((m) => m != 'off', orElse: () => want);
}

// ─── Hot water ─────────────────────────────────────────────────────────

class WaterHeaterInfo {
  const WaterHeaterInfo({required this.temp, required this.target, required this.powerKw, required this.state});

  final double? temp;
  final double? target;
  final double? powerKw;

  /// `heating`, `ready` or `off`.
  final String state;
}

final waterHeaterProvider = Provider<WaterHeaterInfo?>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final config = ref.watch(houseConfigProvider);
  final sensors = ref.watch(individualSensorsProvider);
  final boiler = sensors.where((s) => s.icon == IndividualSensorIconKey.boiler).firstOrNull;

  HaEntity? heater = config.waterHeaterEntityId == null ? null : entities[config.waterHeaterEntityId];
  heater ??= entities.values.where((e) {
    if (e.isUnavailable) return false;
    if (e.domain == 'water_heater') return true;
    final n = e.friendlyName.toLowerCase();
    return e.domain == 'climate' && (n.contains('aqs') || n.contains('água quente') || n.contains('agua quente'));
  }).firstOrNull;
  if (heater == null && boiler == null) return null;

  final tempEntity = entities[config.waterHeaterTempEntityId ?? boiler?.temperatureEntityId ?? ''];
  final temp = numState(tempEntity) ?? numAttr(heater, 'current_temperature');
  final target = numAttr(heater, 'temperature');
  final powerId = config.waterHeaterPowerEntityId ?? boiler?.powerEntityId;
  final power = readPowerKw(entities, powerId, 20);
  final off = heater != null && heater.state == 'off';
  final heating = !off && ((power ?? 0) > 0.05 || (power == null && temp != null && target != null && temp < target - 0.5));
  return WaterHeaterInfo(temp: temp, target: target, powerKw: power, state: off ? 'off' : (heating ? 'heating' : 'ready'));
});

// ─── Lights ────────────────────────────────────────────────────────────

bool _isGroup(HaEntity e) => e.attributes['entity_id'] is List;

/// How many individual lights are on — groups are skipped so a lit room
/// isn't counted once per group it belongs to.
final lightsOnProvider = Provider<int>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  return entities.values.where((e) => e.domain == 'light' && e.isOn && !_isGroup(e)).length;
});

/// Every light (or light switch) the Divisões rooms map, for "Apagar todas
/// as luzes".
final roomLightIdsProvider = Provider<List<String>>(
  (ref) => [
    for (final r in ref.watch(roomEntriesProvider))
      if (r.config.lightEntityId case final id? when id.isNotEmpty) id,
  ],
);

// ─── Locks, gates, alarm ───────────────────────────────────────────────

enum LockKind { door, garage, gate }

class LockInfo {
  const LockInfo({required this.entityId, required this.name, required this.kind, required this.secured, required this.available});

  final String entityId;
  final String name;
  final LockKind kind;
  final bool secured;
  final bool available;

  bool get isCover => entityId.startsWith('cover.');

  String get stateLabel => !available ? 'Indisponível' : (isCover ? (secured ? 'Fechado' : 'Aberto') : (secured ? 'Trancada' : 'Destrancada'));

  String get actionLabel => isCover ? (secured ? 'Abrir' : 'Fechar') : (secured ? 'Destrancar' : 'Trancar');

  String get icon => switch (kind) {
    LockKind.door => KIcons.door,
    LockKind.garage => KIcons.garage,
    LockKind.gate => KIcons.gate,
  };
}

LockInfo _lock(HaEntity e, String name) {
  final dc = e.deviceClass;
  final n = name.toLowerCase();
  final kind = dc == 'garage' || n.contains('garag') ? LockKind.garage : (dc == 'gate' || n.contains('portão') ? LockKind.gate : LockKind.door);
  final secured = e.domain == 'cover' ? e.state == 'closed' : e.state == 'locked';
  return LockInfo(entityId: e.entityId, name: name, kind: kind, secured: secured, available: !e.isUnavailable);
}

/// The locks and gates the Casa screen shows — only the ones chosen in the
/// HA sidebar panel (Flutter Dashboard › Casa › Fechaduras e portões).
/// Deliberately no auto-detection: HA's `lock.*` entities include things
/// like a car's door and charge-cable locks, which don't belong here.
final locksProvider = Provider<List<LockInfo>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final configured = ref.watch(houseConfigProvider.select((c) => c.locks));
  return [
    for (final c in configured)
      if (entities[c.entityId] case final e?) _lock(e, c.name.isEmpty ? e.friendlyName : c.name),
  ];
});

/// Where to pick them, shown while none are configured.
const locksSetupHint = 'Escolha as fechaduras no Home Assistant: Flutter Dashboard › Casa';

enum AlarmMode { off, home, away }

class AlarmInfo {
  const AlarmInfo({required this.entityId, required this.mode, required this.triggered});

  final String entityId;
  final AlarmMode mode;
  final bool triggered;
}

final alarmProvider = Provider<AlarmInfo?>((ref) {
  final id = ref.watch(houseConfigProvider.select((c) => c.alarmEntityId));
  final entities = ref.watch(kioskEntitiesProvider);
  final e = id == null ? null : entities[id];
  if (e == null) return null;
  final mode = switch (e.state) {
    'armed_home' || 'armed_night' => AlarmMode.home,
    'armed_away' || 'armed_vacation' || 'armed_custom_bypass' => AlarmMode.away,
    _ => AlarmMode.off,
  };
  return AlarmInfo(entityId: e.entityId, mode: mode, triggered: e.state == 'triggered');
});

/// Arming can sit in `arming` through an exit delay, so the chosen mode
/// keeps showing for up to a minute and a half.
Future<void> setAlarmMode(WidgetRef ref, AlarmInfo alarm, AlarmMode mode) {
  final want = switch (mode) {
    AlarmMode.off => 'disarmed',
    AlarmMode.home => 'armed_home',
    AlarmMode.away => 'armed_away',
  };
  return ref
      .read(kioskEntitiesProvider.notifier)
      .run(
        [expectEntity(alarm.entityId, state: want, confirmed: (e) => e.state == want || e.state == 'triggered')],
        () => ref
            .read(haWebSocketClientProvider)
            .callService(
              'alarm_control_panel',
              switch (mode) {
                AlarmMode.off => 'alarm_disarm',
                AlarmMode.home => 'alarm_arm_home',
                AlarmMode.away => 'alarm_arm_away',
              },
              target: {'entity_id': alarm.entityId},
            ),
        timeout: mode == AlarmMode.off ? OptimisticLayer.defaultTimeout : const Duration(seconds: 90),
      );
}

// ─── Rooms (Casa grid) ─────────────────────────────────────────────────

/// One room of the Divisões grid and its modal: the area's readings and
/// whatever of light, window, blinds, AC and ventilation it has.
class RoomTile {
  const RoomTile({
    required this.areaId,
    required this.name,
    required this.temp,
    required this.humidity,
    required this.light,
    required this.lightsOn,
    required this.brightness,
    required this.window,
    required this.cover,
    required this.ac,
    required this.vent,
    required this.extra,
    required this.note,
  });

  final String areaId;
  final String name;
  final double? temp;
  final double? humidity;

  final HaEntity? light;

  /// How many lights are on (a group's members), 0 when off.
  final int lightsOn;

  /// 1-100 while on, when the light dims; null otherwise.
  final int? brightness;
  final HaEntity? window;
  final HaEntity? cover;
  final AcUnit? ac;

  /// A fan or extractor (the room's "Linha extra" when it's one).
  final HaEntity? vent;

  /// The "Linha extra" entity otherwise.
  final HaEntity? extra;

  /// The grey line beside the icons: the extra entity, or a high humidity.
  final String? note;

  bool get lightOn => lightsOn > 0;
  bool get windowOpen => window != null && window!.isOn;
  bool get ventOn => vent != null && vent!.isOn;

  /// Blinds open, 0-100 (null without position or blinds).
  int? get coverPosition {
    final c = cover;
    if (c == null || c.isUnavailable) return null;
    final pos = numAttr(c, 'current_position');
    if (pos != null) return pos.round();
    return c.state == 'closed' ? 0 : 100;
  }

  bool get coverSettable => ((cover?.attributes['supported_features'] as num?)?.toInt() ?? 0) & 4 != 0;

  bool get dimmable {
    final modes = (light?.attributes['supported_color_modes'] as List?)?.whereType<String>().toList();
    if (light?.domain != 'light') return false;
    return modes == null ? light!.attributes['brightness'] != null : modes.any((m) => m != 'onoff');
  }
}

bool _isVent(HaEntity e) =>
    e.domain == 'fan' ||
    ((e.domain == 'switch' || e.domain == 'input_boolean') &&
        RegExp('extrat|ventila|exaust', caseSensitive: false).hasMatch('${e.entityId} ${e.friendlyName}'));

String? extraText(HaEntity e) {
  if (e.isUnavailable) return null;
  if (e.domain == 'lock') return '${e.friendlyName} ${e.state == 'locked' ? 'trancada' : 'aberta'}';
  if (e.domain == 'cover') return '${e.friendlyName} ${e.state == 'closed' ? 'fechado' : 'aberto'}';
  return '${e.friendlyName} · ${e.displayState}';
}

final roomTilesProvider = Provider<List<RoomTile>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final rooms = ref.watch(roomEntriesProvider);
  final units = {for (final u in ref.watch(acUnitsProvider)) u.entityId: u};
  return [
    for (final r in rooms)
      () {
        HaEntity? get(String? id) {
          final e = entities[id ?? ''];
          return e == null || e.isUnavailable ? null : e;
        }

        final light = get(r.config.lightEntityId);
        var count = 0;
        int? bri;
        if (light != null && light.isOn) {
          final members = (light.attributes['entity_id'] as List?)?.whereType<String>().toList();
          count = members == null ? 1 : members.where((m) => entities[m]?.isOn ?? false).length.clamp(1, 99);
          final b = numAttr(light, 'brightness');
          if (b != null) bri = (b / 255 * 100).round().clamp(1, 100);
        }
        final secondary = get(r.config.secondaryEntityId);
        final vent = secondary != null && _isVent(secondary) ? secondary : null;
        final extra = vent == null ? secondary : null;
        final hum = numState(entities[r.area.humidityEntityId ?? '']);
        return RoomTile(
          areaId: r.areaId,
          name: r.name,
          temp: numState(entities[r.area.temperatureEntityId ?? '']),
          humidity: hum,
          light: light,
          lightsOn: count,
          brightness: bri,
          window: get(r.config.windowEntityId),
          cover: get(r.config.coverEntityId),
          ac: units[r.config.climateEntityId],
          vent: vent,
          extra: extra,
          note: (extra == null ? null : extraText(extra)) ?? (hum != null && hum >= 65 ? 'Humidade alta' : null),
        );
      }(),
  ];
});

/// Open windows: the rooms' window sensors, or — none mapped — every
/// window binary sensor.
final openWindowsProvider = Provider<int>((ref) {
  final rooms = ref.watch(roomTilesProvider).where((r) => r.window != null).toList();
  if (rooms.isNotEmpty) return rooms.where((r) => r.windowOpen).length;
  return ref.watch(kioskEntitiesProvider).values.where((e) => e.domain == 'binary_sensor' && e.deviceClass == 'window' && e.isOn).length;
});

Future<void> setBrightness(WidgetRef ref, String entityId, int pct) => ref.read(kioskEntitiesProvider.notifier).run([
  expectEntity(
    entityId,
    state: 'on',
    attrs: {'brightness': (pct * 255 / 100).round()},
    confirmed: (e) => e.isOn && ((numAttr(e, 'brightness') ?? 0) / 255 * 100 - pct).abs() < 2,
  ),
], () => ref.read(haWebSocketClientProvider).callService('light', 'turn_on', target: {'entity_id': entityId}, serviceData: {'brightness_pct': pct}));

/// Blinds to [pos]% (0 closed, 100 open). Covers without a position just
/// open or close.
Future<void> setCover(WidgetRef ref, RoomTile room, int pos) {
  final id = room.cover!.entityId;
  final client = ref.read(haWebSocketClientProvider);
  final settable = room.coverSettable;
  return ref
      .read(kioskEntitiesProvider.notifier)
      .run(
        [
          OptimisticChange(
            id,
            slot: 'position',
            patch: (e) => e.copyWith(state: pos == 0 ? 'closed' : 'open', attributes: {...e.attributes, 'current_position': pos}),
            // A moving cover counts: it can take a minute to get there.
            confirmed: (e) =>
                e.state == 'opening' || e.state == 'closing' || ((numAttr(e, 'current_position') ?? (e.state == 'closed' ? 0 : 100)) - pos).abs() <= 2,
          ),
        ],
        () => settable && pos > 0 && pos < 100
            ? client.callService('cover', 'set_cover_position', target: {'entity_id': id}, serviceData: {'position': pos})
            : client.callService('cover', pos == 0 ? 'close_cover' : 'open_cover', target: {'entity_id': id}),
        timeout: const Duration(seconds: 60),
      );
}

Future<void> toggleEntity(WidgetRef ref, HaEntity e, bool on) => ref.read(kioskEntitiesProvider.notifier).run([
  expectEntity(e.entityId, state: on ? 'on' : 'off'),
], () => ref.read(haWebSocketClientProvider).callService(e.domain, on ? 'turn_on' : 'turn_off', target: {'entity_id': e.entityId}));

Future<void> toggleLight(WidgetRef ref, String entityId, bool on) {
  final domain = entityId.split('.').first;
  return ref.read(kioskEntitiesProvider.notifier).run(
    [expectEntity(entityId, state: on ? 'on' : 'off')],
    () =>
        ref.read(haWebSocketClientProvider).callService(domain == 'switch' ? 'switch' : 'light', on ? 'turn_on' : 'turn_off', target: {'entity_id': entityId}),
  );
}

Future<void> allLightsOff(WidgetRef ref) async {
  final entities = ref.read(kioskEntitiesProvider);
  final ids = {
    ...ref.read(roomLightIdsProvider),
    for (final e in entities.values)
      if (e.domain == 'light' && e.isOn) e.entityId,
  }.where((id) => entities[id]?.isOn ?? false).toList();
  final lights = ids.where((id) => id.startsWith('light.')).toList();
  final switches = ids.where((id) => id.startsWith('switch.')).toList();
  final client = ref.read(haWebSocketClientProvider);
  await ref.read(kioskEntitiesProvider.notifier).run(
    [for (final id in ids) expectEntity(id, state: 'off')],
    () => Future.wait([
      if (lights.isNotEmpty) client.callService('light', 'turn_off', target: {'entity_id': lights}),
      if (switches.isNotEmpty) client.callService('switch', 'turn_off', target: {'entity_id': switches}),
    ]),
  );
}

// ─── Cars ──────────────────────────────────────────────────────────────

enum EvState { charging, waiting, unplugged, unknown }

class CarInfo {
  const CarInfo({
    required this.name,
    required this.kind,
    required this.level,
    required this.rangeKm,
    required this.limit,
    required this.state,
    required this.powerKw,
    required this.locked,
    required this.place,
    required this.updated,
  });

  final String name;
  final CarKind kind;

  /// Battery (electric) or tank (fuel), 0-100.
  final double? level;
  final double? rangeKm;
  final double? limit;
  final EvState state;
  final double? powerKw;

  /// Fuel cars: trancado or not, null without a lock entity.
  final bool? locked;

  /// "Em casa" (or the zone it's in) when the car has a home entity.
  final String? place;
  final DateTime? updated;

  bool get isFuel => kind == CarKind.fuel;
}

/// Whether [e] (a device tracker, person or binary sensor) says the car is
/// at home.
bool _atHome(HaEntity? e) => e != null && !e.isUnavailable && (e.domain == 'binary_sensor' ? e.isOn : e.state == 'home');

CarInfo _car(CarConfig c, Map<String, HaEntity> entities) {
  final home = entities[c.homeEntityId ?? ''];
  final place = home == null || home.isUnavailable
      ? null
      : _atHome(home)
      ? 'Em casa'
      : (home.domain == 'binary_sensor' || home.state == 'not_home' ? 'Fora de casa' : home.state);
  final range = numState(entities[c.rangeEntityId ?? '']);
  if (c.kind == CarKind.fuel) {
    final fuel = entities[c.fuelEntityId ?? ''];
    final lock = entities[c.lockEntityId ?? ''];
    return CarInfo(
      name: c.name.trim().isNotEmpty ? c.name : 'Carro',
      kind: c.kind,
      level: numState(fuel),
      rangeKm: range,
      limit: null,
      state: EvState.unknown,
      powerKw: null,
      locked: lock == null || lock.isUnavailable ? null : (lock.domain == 'lock' ? lock.state == 'locked' : !lock.isOn),
      place: place,
      updated: fuel?.lastUpdated.toLocal(),
    );
  }
  final charging = entities[c.chargingEntityId ?? ''];
  final plug = entities[c.plugConnectedEntityId ?? ''];
  final battery = entities[c.batterySocEntityId ?? ''];
  EvState state;
  if (charging != null && !charging.isUnavailable && truthy(charging)) {
    state = EvState.charging;
  } else if (plug != null && !plug.isUnavailable) {
    final s = plug.state.toLowerCase();
    final plugged = s.startsWith('plugged') || s == 'on' || s == 'connected' || s == 'true';
    state = plugged ? EvState.waiting : EvState.unplugged;
  } else {
    state = charging == null || charging.isUnavailable ? EvState.unknown : EvState.unplugged;
  }
  return CarInfo(
    name: c.name.trim().isNotEmpty ? c.name : _carNameFrom(battery),
    kind: c.kind,
    level: numState(battery),
    rangeKm: range,
    limit: numState(entities[c.chargeLimitEntityId ?? '']),
    state: state,
    powerKw: readPowerKw(entities, c.chargePowerEntityId, 20),
    locked: null,
    place: place,
    updated: battery?.lastUpdated.toLocal(),
  );
}

/// "Megane Bateria" → "Megane": the battery entity's name without the
/// word for battery, for a car saved without a name of its own.
String _carNameFrom(HaEntity? battery) {
  final n = battery?.friendlyName.replaceAll(RegExp(r'\s*(n[íi]vel d[ae] )?(bateria|battery( level)?|soc)\s*$', caseSensitive: false), '').trim();
  return n == null || n.isEmpty ? 'Carro' : n;
}

/// The cars the screen shows: the first two, in the panel's order, that
/// are at home (a car with no home entity always counts).
final carsProvider = Provider<List<CarInfo>>((ref) {
  final config = ref.watch(carsConfigProvider);
  final entities = ref.watch(kioskEntitiesProvider);
  return [
    for (final c in config.cars)
      if (c.homeEntityId == null || _atHome(entities[c.homeEntityId])) _car(c, entities),
  ].take(2).toList();
});

// ─── Energy ────────────────────────────────────────────────────────────

class EnergyConsumer {
  const EnergyConsumer({required this.name, required this.icon, required this.kw, required this.temp});

  final String name;
  final IndividualSensorIconKey icon;
  final double? kw;
  final double? temp;
}

class EnergyInfo {
  const EnergyInfo({required this.gridKw, required this.solarKw, required this.batteryKw, required this.soc, required this.homeKw, required this.consumers});

  /// + importing / − exporting.
  final double? gridKw;
  final double? solarKw;

  /// + discharging / − charging.
  final double? batteryKw;
  final double? soc;
  final double? homeKw;
  final List<EnergyConsumer> consumers;

  bool get isEmpty => gridKw == null && solarKw == null && batteryKw == null && homeKw == null;
}

final energyInfoProvider = Provider<EnergyInfo>((ref) {
  final c = ref.watch(energyEntityConfigProvider);
  final sensors = ref.watch(individualSensorsProvider);
  final entities = ref.watch(kioskEntitiesProvider);
  return EnergyInfo(
    gridKw: readPowerKw(entities, c.gridPowerEntityId, c.gridZeroThresholdW),
    solarKw: readPowerKw(entities, c.solarPowerEntityId, c.solarZeroThresholdW),
    batteryKw: readPowerKw(entities, c.batteryPowerEntityId, c.batteryZeroThresholdW),
    soc: numState(entities[c.batterySocEntityId ?? '']),
    homeKw: readPowerKw(entities, c.homePowerEntityId, c.homeZeroThresholdW),
    consumers: [
      for (final s in sensors.take(4))
        EnergyConsumer(name: s.name, icon: s.icon, kw: readPowerKw(entities, s.powerEntityId, 5), temp: numState(entities[s.temperatureEntityId ?? ''])),
    ],
  );
});

// ─── Weather (header) ──────────────────────────────────────────────────

class WeatherNow {
  const WeatherNow({required this.condition, required this.temp, required this.place});

  final String? condition;
  final double? temp;
  final String? place;
}

final weatherNowProvider = Provider<WeatherNow>((ref) {
  final t = ref.watch(temperatureEntityConfigProvider);
  final entities = ref.watch(kioskEntitiesProvider);
  final weather = entities[t.weatherStateEntityId ?? ''] ?? entities.values.where((e) => e.domain == 'weather').firstOrNull;
  final exterior = numState(entities[t.exteriorTempEntityId ?? '']);
  return WeatherNow(
    condition: weather == null || weather.isUnavailable ? null : weather.state,
    temp: exterior ?? numAttr(weather, 'temperature'),
    place: weather?.friendlyName,
  );
});

String weatherLabel(String? c) => switch (c) {
  'sunny' => 'Sol',
  'clear-night' => 'Céu limpo',
  'partlycloudy' => 'Parcialmente nublado',
  'cloudy' => 'Nublado',
  'rainy' => 'Chuva',
  'pouring' => 'Chuva forte',
  'lightning' || 'lightning-rainy' => 'Trovoada',
  'snowy' || 'snowy-rainy' => 'Neve',
  'hail' => 'Granizo',
  'fog' => 'Nevoeiro',
  'windy' || 'windy-variant' => 'Vento',
  'exceptional' => 'Tempo excecional',
  _ => '',
};

String weatherIcon(String? c) => switch (c) {
  'sunny' => KIcons.wSunny,
  'clear-night' => KIcons.wNight,
  'partlycloudy' => KIcons.wPartlyCloudy,
  'cloudy' => KIcons.wCloudy,
  'rainy' || 'pouring' => KIcons.wRainy,
  'lightning' || 'lightning-rainy' => KIcons.wStorm,
  'snowy' || 'snowy-rainy' || 'hail' => KIcons.wSnow,
  'fog' => KIcons.wFog,
  'windy' || 'windy-variant' => KIcons.wWind,
  _ => KIcons.wPartlyCloudy,
};
