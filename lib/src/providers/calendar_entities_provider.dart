import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_entities_store.dart';

final calendarEntitiesStoreProvider = Provider<CalendarEntitiesStore>((ref) => CalendarEntitiesStore());

/// Configured calendars persisted from a previous session, read once at
/// startup.
final savedCalendarEntriesProvider = FutureProvider<List<CalendarEntryConfig>>((ref) {
  return ref.watch(calendarEntitiesStoreProvider).read();
});

/// The calendar list currently in use — set from [savedCalendarEntriesProvider]
/// at startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the calendar card/sheet pick it up live without a
/// restart.
final calendarEntriesProvider = StateProvider<List<CalendarEntryConfig>>((ref) => const []);
