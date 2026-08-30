import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rooms_store.dart';

final roomsStoreProvider = Provider<RoomsStore>((ref) => RoomsStore());

/// Config persisted from a previous session, read once at startup.
final savedRoomsProvider = FutureProvider<List<RoomConfig>>((ref) {
  return ref.watch(roomsStoreProvider).read();
});

/// The room list currently in use — set from [savedRoomsProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the Divisões page picks it up live without a
/// restart. Starts empty, same as `calendarEntriesProvider`/
/// `individualSensorsProvider` — this app has no rooms baked in.
final roomsProvider = StateProvider<List<RoomConfig>>((ref) => const []);
