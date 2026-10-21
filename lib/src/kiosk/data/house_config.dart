import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ha_client/ha_websocket_client.dart';
import '../../providers/ha_providers.dart';

/// A named entity in one of the Casa screen's lists (scenes, locks,
/// cameras). An empty [name] falls back to the entity's own friendly name.
class NamedEntity {
  const NamedEntity({required this.name, required this.entityId});

  final String name;
  final String entityId;

  factory NamedEntity.fromJson(Map<String, dynamic> json) =>
      NamedEntity(name: (json['name'] as String? ?? '').trim(), entityId: (json['entityId'] as String? ?? '').trim());
}

/// What the Casa screen and the Início "Casa" section show, as mapped in
/// the HA sidebar panel ("Casa"). Everything is optional: an unset
/// alarm hides the alarm controls, unset lists fall back to what HA itself
/// has (every `scene.*`, every `lock.*` plus garage/gate covers).
class HouseConfig {
  const HouseConfig({
    this.alarmEntityId,
    this.waterHeaterEntityId,
    this.waterHeaterTempEntityId,
    this.waterHeaterPowerEntityId,
    this.scenes = const [],
    this.locks = const [],
    this.cameras = const [],
  });

  /// `alarm_control_panel.*`
  final String? alarmEntityId;

  /// `climate.*` or `water_heater.*` for the hot-water tank (target
  /// temperature, heating or not).
  final String? waterHeaterEntityId;

  /// Optional overrides for the tank's temperature and power readings —
  /// otherwise taken from the energy card's "Bomba de calor (AQS)"
  /// individual sensor, then from [waterHeaterEntityId] itself.
  final String? waterHeaterTempEntityId;
  final String? waterHeaterPowerEntityId;

  final List<NamedEntity> scenes;
  final List<NamedEntity> locks;
  final List<NamedEntity> cameras;

  HouseConfig copyWith({List<NamedEntity>? scenes, List<NamedEntity>? locks, List<NamedEntity>? cameras}) => HouseConfig(
    alarmEntityId: alarmEntityId,
    waterHeaterEntityId: waterHeaterEntityId,
    waterHeaterTempEntityId: waterHeaterTempEntityId,
    waterHeaterPowerEntityId: waterHeaterPowerEntityId,
    scenes: scenes ?? this.scenes,
    locks: locks ?? this.locks,
    cameras: cameras ?? this.cameras,
  );
}

class HouseConfigStore {
  HouseConfigStore(this._client);

  final HaWebSocketClient _client;

  Future<List<NamedEntity>> _list(String key) async {
    final raw = await _client.getSettings(key);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => NamedEntity.fromJson(m.cast<String, dynamic>())).where((e) => e.entityId.isNotEmpty).toList();
  }

  Future<HouseConfig> read() async {
    final raw = await _client.getSettings('house_screen');
    final m = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
    String? s(String k) {
      final v = m[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return HouseConfig(
      alarmEntityId: s('alarmEntityId'),
      waterHeaterEntityId: s('waterHeaterEntityId'),
      waterHeaterTempEntityId: s('waterHeaterTempEntityId'),
      waterHeaterPowerEntityId: s('waterHeaterPowerEntityId'),
      scenes: await _list('house_scenes'),
      locks: await _list('house_locks'),
      cameras: await _list('house_cameras'),
    );
  }
}

final houseConfigStoreProvider = Provider<HouseConfigStore>((ref) => HouseConfigStore(ref.watch(haWebSocketClientProvider)));

final savedHouseConfigProvider = FutureProvider<HouseConfig>((ref) async {
  await haReady(ref);
  return ref.watch(houseConfigStoreProvider).read();
});

final houseConfigProvider = StateProvider<HouseConfig>((ref) => const HouseConfig());
