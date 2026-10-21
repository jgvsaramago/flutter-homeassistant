import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_entities_store.dart';
import 'ha_providers.dart';

final calendarEntitiesStoreProvider = Provider<CalendarEntitiesStore>(
  (ref) => CalendarEntitiesStore(ref.watch(haWebSocketClientProvider)),
);

/// Configured calendars persisted from a previous session, read once at
/// startup — waits for the HA connection first, same idiom as
/// `areaByEntityIdProvider`.
final savedCalendarEntriesProvider = FutureProvider<List<CalendarEntryConfig>>((ref) async {
  await haReady(ref);
  return ref.watch(calendarEntitiesStoreProvider).read();
});

/// The config currently in use — set from [savedCalendarEntriesProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final calendarEntriesProvider = StateProvider<List<CalendarEntryConfig>>((ref) => const []);
