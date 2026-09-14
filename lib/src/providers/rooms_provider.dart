import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ha_area.dart';
import '../models/ha_floor.dart';
import 'ha_providers.dart';
import 'rooms_store.dart';

final roomsStoreProvider = Provider<RoomsStore>((ref) => RoomsStore(ref.watch(haWebSocketClientProvider)));

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection to actually be up first (`getSettings` needs an
/// authenticated websocket), same idiom as `areaByEntityIdProvider`. Also
/// waits on the area registry: `RoomsStore.read` needs the current area
/// list to validate/migrate saved entries against (see its own doc).
final savedRoomsProvider = FutureProvider<List<RoomConfig>>((ref) async {
  await ref.watch(entitiesProvider.future);
  final areas = await ref.watch(savedAreasProvider.future);
  return ref.watch(roomsStoreProvider).read(areas);
});

/// The room list currently in use — set from [savedRoomsProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the Divisões page picks it up live without a
/// restart. Starts empty, same as `calendarEntriesProvider`/
/// `individualSensorsProvider` — this app has no rooms baked in.
final roomsProvider = StateProvider<List<RoomConfig>>((ref) => const []);

/// One configured room, fully resolved against live HA data: the area it
/// mirrors (name, floor, temperature/humidity sensors) plus this app's own
/// entity mapping for it. Everything that renders a room reads this, never
/// a bare [RoomConfig] — see [roomEntriesProvider].
class RoomEntry {
  const RoomEntry({required this.area, required this.floor, required this.config});

  final HaArea area;

  /// The floor [area] belongs to, if HA has one assigned — null both when
  /// the area has no `floor_id` and when that id doesn't match any floor
  /// (registry momentarily out of sync, say).
  final HaFloor? floor;
  final RoomConfig config;

  String get areaId => area.areaId;
  String get name => area.name;
}

/// [roomsProvider]'s saved entity mappings, resolved against the live area
/// (and floor) registries. A mapping whose area has disappeared from HA
/// since it was saved is silently dropped here rather than shown with a
/// blank name — `settingsHydrationProvider` already drops those at load
/// time via `RoomsStore.read`, but this also covers an area deleted in HA
/// *after* this session's own hydration already ran.
final roomEntriesProvider = Provider<List<RoomEntry>>((ref) {
  final configs = ref.watch(roomsProvider);
  final areas = ref.watch(areasProvider);
  final floors = ref.watch(floorsProvider);
  final areaById = {for (final a in areas) a.areaId: a};
  final floorById = {for (final f in floors) f.floorId: f};

  return [
    for (final config in configs)
      if (areaById[config.areaId] case final area?)
        RoomEntry(area: area, floor: area.floorId == null ? null : floorById[area.floorId], config: config),
  ];
});
