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
import '../../utils/power_reading.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'house_config.dart';
import 'kiosk_entities.dart';
import 'pt_dates.dart';

Future<void> _call(Ref ref, String domain, String service, String entityId, [Map<String, dynamic>? data]) =>
    ref.read(haWebSocketClientProvider).callService(domain, service, target: {'entity_id': entityId}, serviceData: data);

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

  Future<void> power(AcUnit u, bool on) => _call(_ref, 'climate', on ? 'turn_on' : 'turn_off', u.entityId);

  Future<void> target(AcUnit u, double t) => _call(_ref, 'climate', 'set_temperature', u.entityId, {'temperature': t.clamp(u.min, u.max)});

  Future<void> mode(AcUnit u, AcMode m) => _call(_ref, 'climate', 'set_hvac_mode', u.entityId, {'hvac_mode': u.hvacFor(m)});

  Future<void> allOff(List<AcUnit> units) => Future.wait([for (final u in units.where((u) => u.on)) power(u, false)]);
}

final acActionsProvider = Provider<AcActions>((ref) => AcActions(ref));

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

final locksProvider = Provider<List<LockInfo>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final configured = ref.watch(houseConfigProvider.select((c) => c.locks));
  if (configured.isNotEmpty) {
    return [
      for (final c in configured)
        if (entities[c.entityId] case final e?) _lock(e, c.name.isEmpty ? e.friendlyName : c.name),
    ];
  }
  final out = [
    for (final e in entities.values)
      if (e.domain == 'lock' || (e.domain == 'cover' && (e.deviceClass == 'garage' || e.deviceClass == 'gate'))) _lock(e, e.friendlyName),
  ]..sort((a, b) => a.kind.index != b.kind.index ? a.kind.index - b.kind.index : a.name.compareTo(b.name));
  return out;
});

class LockActions {
  LockActions(this._ref);

  final Ref _ref;

  Future<void> toggle(LockInfo l) {
    if (l.isCover) return _call(_ref, 'cover', l.secured ? 'open_cover' : 'close_cover', l.entityId);
    return _call(_ref, 'lock', l.secured ? 'unlock' : 'lock', l.entityId);
  }
}

final lockActionsProvider = Provider<LockActions>((ref) => LockActions(ref));

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

Future<void> setAlarmMode(WidgetRef ref, AlarmInfo alarm, AlarmMode mode) => ref
    .read(haWebSocketClientProvider)
    .callService(
      'alarm_control_panel',
      switch (mode) {
        AlarmMode.off => 'alarm_disarm',
        AlarmMode.home => 'alarm_arm_home',
        AlarmMode.away => 'alarm_arm_away',
      },
      target: {'entity_id': alarm.entityId},
    );

// ─── Scenes ────────────────────────────────────────────────────────────

class SceneInfo {
  const SceneInfo({required this.entityId, required this.name, required this.icon, required this.lastRun});

  final String entityId;
  final String name;
  final String icon;
  final DateTime? lastRun;
}

String sceneIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('dia') || n.contains('manhã') || n.contains('acordar')) return KIcons.sunrise;
  if (n.contains('sair') || n.contains('fora') || n.contains('ausente')) return KIcons.leave;
  if (n.contains('jantar') || n.contains('refei') || n.contains('almoço')) return KIcons.meals;
  if (n.contains('cinema') || n.contains('filme') || n.contains('tv')) return KIcons.tv;
  if (n.contains('noite') || n.contains('dormir')) return KIcons.moon;
  return KIcons.bulb;
}

final scenesProvider = Provider<List<SceneInfo>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final configured = ref.watch(houseConfigProvider.select((c) => c.scenes));
  SceneInfo info(HaEntity e, String name) => SceneInfo(
    entityId: e.entityId,
    name: name,
    icon: sceneIcon(name),
    lastRun: e.domain == 'scene' ? DateTime.tryParse(e.state)?.toLocal() : e.lastChanged.toLocal(),
  );
  if (configured.isNotEmpty) {
    return [
      for (final c in configured)
        if (entities[c.entityId] case final e?) info(e, c.name.isEmpty ? e.friendlyName : c.name),
    ];
  }
  final all = [
    for (final e in entities.values)
      if (e.domain == 'scene' && e.state != 'unavailable') info(e, e.friendlyName),
  ]..sort((a, b) => a.name.compareTo(b.name));
  return all.take(5).toList();
});

/// The scene run most recently, if within the last 12 hours — the one the
/// design highlights as "on". Scenes have no on/off state in HA.
final activeSceneProvider = Provider<String?>((ref) {
  final scenes = ref.watch(scenesProvider);
  final cutoff = DateTime.now().subtract(const Duration(hours: 12));
  SceneInfo? best;
  for (final s in scenes) {
    if (s.lastRun == null || s.lastRun!.isBefore(cutoff)) continue;
    if (best == null || s.lastRun!.isAfter(best.lastRun!)) best = s;
  }
  return best?.entityId;
});

Future<void> runScene(WidgetRef ref, SceneInfo s) =>
    ref.read(haWebSocketClientProvider).callService(s.entityId.split('.').first, 'turn_on', target: {'entity_id': s.entityId});

// ─── Security sensors ──────────────────────────────────────────────────

class SensorLine {
  const SensorLine(this.text, this.color);

  final String text;
  final Color color;
}

final securitySensorsProvider = Provider<List<SensorLine>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final areas = ref.watch(areaByEntityIdProvider).valueOrNull ?? const <String, String>{};
  final openings = <HaEntity>[], motion = <HaEntity>[], alerts = <HaEntity>[];
  for (final e in entities.values) {
    if (e.domain != 'binary_sensor' || e.isUnavailable) continue;
    switch (e.deviceClass) {
      case 'door' || 'window' || 'opening' || 'garage_door':
        openings.add(e);
      case 'motion' || 'occupancy' || 'presence':
        motion.add(e);
      case 'smoke' || 'moisture' || 'gas' || 'carbon_monoxide':
        alerts.add(e);
    }
  }
  final lines = <SensorLine>[];
  if (openings.isNotEmpty) {
    final open = openings.where((e) => e.isOn).toList();
    lines.add(
      open.isEmpty
          ? const SensorLine('Janelas e portas: todas fechadas', KColors.green)
          : SensorLine('Janelas e portas: ${open.length == 1 ? open.first.friendlyName : '${open.length} abertas'}', KColors.amber),
    );
  }
  if (motion.isNotEmpty) {
    final active = motion.where((e) => e.isOn).toList();
    if (active.isNotEmpty) {
      final where = areas[active.first.entityId] ?? active.first.friendlyName;
      lines.add(SensorLine('Movimento: ${where.toLowerCase()}, agora', KColors.amber));
    } else {
      final last = (motion.toList()..sort((a, b) => b.lastChanged.compareTo(a.lastChanged))).first;
      final mins = DateTime.now().difference(last.lastChanged).inMinutes;
      final where = (areas[last.entityId] ?? last.friendlyName).toLowerCase();
      final ago = mins < 1 ? 'agora mesmo' : mins < 60 ? 'há $mins min' : (mins < 24 * 60 ? 'há ${mins ~/ 60} h' : 'há mais de um dia');
      lines.add(SensorLine('Movimento: $where, $ago', KColors.faint2));
    }
  }
  if (alerts.isNotEmpty) {
    final on = alerts.where((e) => e.isOn).toList();
    lines.add(on.isEmpty ? const SensorLine('Fumo e inundação: sem alertas', KColors.green) : SensorLine('Alerta: ${on.first.friendlyName}', KColors.red));
  }
  return lines;
});

// ─── Rooms (Casa grid) ─────────────────────────────────────────────────

class RoomInfoLine {
  const RoomInfoLine(this.text, this.dot);

  final String text;
  final Color dot;
}

class RoomTile {
  const RoomTile({required this.name, required this.temp, required this.info, required this.lightId, required this.lightOn, required this.lightLabel});

  final String name;
  final double? temp;
  final List<RoomInfoLine> info;
  final String? lightId;
  final bool lightOn;
  final String lightLabel;
}

String _coverText(HaEntity c) {
  final pos = numAttr(c, 'current_position');
  if (c.state == 'closed' || pos == 0) return 'Estores fechados';
  if (pos != null && pos < 100) return 'Estores a ${pos.round()}%';
  if (c.state == 'opening') return 'Estores a abrir';
  if (c.state == 'closing') return 'Estores a fechar';
  return 'Estores abertos';
}

final roomTilesProvider = Provider<List<RoomTile>>((ref) {
  final entities = ref.watch(kioskEntitiesProvider);
  final rooms = ref.watch(roomEntriesProvider);
  return [
    for (final r in rooms)
      () {
        final info = <RoomInfoLine>[];
        final climate = entities[r.config.climateEntityId ?? ''];
        if (climate != null && climate.domain == 'climate') {
          final on = climate.state != 'off' && !climate.isUnavailable;
          info.add(
            on
                ? RoomInfoLine('Ar condicionado · ${ptDeg(numAttr(climate, 'temperature'))}', _acModeOf(climate.state)?.color ?? KColors.orange)
                : const RoomInfoLine('Ar condicionado desligado', KColors.ring),
          );
        }
        final cover = entities[r.config.coverEntityId ?? ''];
        if (cover != null && !cover.isUnavailable) info.add(RoomInfoLine(_coverText(cover), KColors.faint2));
        final window = entities[r.config.windowEntityId ?? ''];
        if (window != null && !window.isUnavailable) {
          info.add(window.isOn ? const RoomInfoLine('Janela aberta', KColors.amber) : const RoomInfoLine('Janelas fechadas', KColors.green));
        }
        final hum = numState(entities[r.area.humidityEntityId ?? '']);
        if (hum != null) info.add(RoomInfoLine('Humidade ${hum.round()}%', KColors.blue));
        final secondary = entities[r.config.secondaryEntityId ?? ''];
        if (secondary != null && !secondary.isUnavailable && info.length < 3) {
          final text = secondary.domain == 'lock'
              ? (secondary.state == 'locked' ? '${secondary.friendlyName} trancada' : '${secondary.friendlyName} aberta')
              : '${secondary.friendlyName} · ${secondary.displayState}';
          info.add(RoomInfoLine(text, secondary.domain == 'lock' && secondary.state == 'locked' ? KColors.green : KColors.faint2));
        }

        final light = entities[r.config.lightEntityId ?? ''];
        var label = 'Luzes apagadas';
        final on = light?.isOn ?? false;
        if (light != null && on) {
          final members = (light.attributes['entity_id'] as List?)?.whereType<String>().toList();
          final count = members == null ? 1 : members.where((m) => entities[m]?.isOn ?? false).length.clamp(1, 99);
          final bri = numAttr(light, 'brightness');
          label = '$count ${count == 1 ? 'luz' : 'luzes'}${bri == null ? '' : ' · ${(bri / 255 * 100).round()}%'}';
        }
        return RoomTile(
          name: r.name,
          temp: numState(entities[r.area.temperatureEntityId ?? '']),
          info: info.take(3).toList(),
          lightId: light?.entityId,
          lightOn: on,
          lightLabel: label,
        );
      }(),
  ];
});

Future<void> toggleLight(WidgetRef ref, String entityId, bool on) {
  final domain = entityId.split('.').first;
  return ref.read(haWebSocketClientProvider).callService(domain == 'switch' ? 'switch' : 'light', on ? 'turn_on' : 'turn_off', target: {'entity_id': entityId});
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
  await Future.wait([
    if (lights.isNotEmpty) client.callService('light', 'turn_off', target: {'entity_id': lights}),
    if (switches.isNotEmpty) client.callService('switch', 'turn_off', target: {'entity_id': switches}),
  ]);
}

// ─── EV cars ───────────────────────────────────────────────────────────

enum EvState { charging, waiting, unplugged, unknown }

class EvCarInfo {
  const EvCarInfo({
    required this.name,
    required this.battery,
    required this.rangeKm,
    required this.limit,
    required this.state,
    required this.powerKw,
    required this.updated,
  });

  final String name;
  final double? battery;
  final double? rangeKm;
  final double? limit;
  final EvState state;
  final double? powerKw;
  final DateTime? updated;
}

EvCarInfo _ev(EvCarConfig c, Map<String, HaEntity> entities) {
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
  return EvCarInfo(
    name: c.name,
    battery: numState(battery),
    rangeKm: numState(entities[c.rangeEntityId ?? '']),
    limit: numState(entities[c.chargeLimitEntityId ?? '']),
    state: state,
    powerKw: readPowerKw(entities, c.chargePowerEntityId, 20),
    updated: battery?.lastUpdated.toLocal(),
  );
}

final evCarsProvider = Provider<List<EvCarInfo>>((ref) {
  final config = ref.watch(evCarsConfigProvider);
  final entities = ref.watch(kioskEntitiesProvider);
  return [_ev(config.left, entities), _ev(config.right, entities)];
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
