import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'rooms_store.dart';

final roomsStoreProvider = Provider<RoomsStore>((ref) => RoomsStore(ref.watch(haWebSocketClientProvider)));

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection to actually be up first (`getSettings` needs an
/// authenticated websocket), same idiom as `areaByEntityIdProvider`.
final savedRoomsProvider = FutureProvider<List<RoomConfig>>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(roomsStoreProvider).read();
});

/// The room list currently in use — set from [savedRoomsProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the Divisões page picks it up live without a
/// restart. Starts empty, same as `calendarEntriesProvider`/
/// `individualSensorsProvider` — this app has no rooms baked in.
final roomsProvider = StateProvider<List<RoomConfig>>((ref) => const []);
