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
  await ref.watch(entitiesProvider.future);
  return ref.watch(calendarEntitiesStoreProvider).read();
});

/// The calendar list currently in use — set from [savedCalendarEntriesProvider]
/// at startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the calendar card/sheet pick it up live without a
/// restart.
final calendarEntriesProvider = StateProvider<List<CalendarEntryConfig>>((ref) => const []);
