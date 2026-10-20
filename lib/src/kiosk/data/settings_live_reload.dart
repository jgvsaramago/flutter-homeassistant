import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_entities_provider.dart';
import '../../providers/energy_entities_provider.dart';
import '../../providers/ev_cars_provider.dart';
import '../../providers/ha_providers.dart';
import '../../providers/individual_sensors_provider.dart';
import '../../providers/rooms_provider.dart';
import '../../providers/temperature_entities_provider.dart';
import 'calendar_data.dart';
import 'family_data.dart';
import 'house_config.dart';

/// Applies a setting saved in HA's sidebar panel as soon as it's saved,
/// instead of at the next restart: re-reads just that key and swaps it in.
/// Watched by the shell, so it lives as long as the app.
///
/// Meals, tasks and list icons aren't here — this screen edits those
/// itself, and they already reload whenever their page is opened.
final settingsLiveReloadProvider = Provider<void>((ref) {
  final sub = ref.watch(haWebSocketClientProvider).settingsUpdates.listen((key) {
    _reload(ref, key).catchError((Object e) => debugPrint('[settings] live reload of $key failed: $e'));
  });
  ref.onDispose(sub.cancel);
});

Future<void> _reload(Ref ref, String key) async {
  Future<T> fresh<T>(FutureProvider<T> saved) {
    ref.invalidate(saved);
    return ref.read(saved.future);
  }

  switch (key) {
    case 'family_members':
      ref.read(familyConfigProvider.notifier).state = await fresh(savedFamilyProvider);
      ref.read(calendarRefreshProvider.notifier).state++;
    case 'calendar_entities':
      ref.read(calendarEntriesProvider.notifier).state = await fresh(savedCalendarEntriesProvider);
      ref.read(calendarRefreshProvider.notifier).state++;
    case 'temperature_entities':
      ref.read(temperatureEntityConfigProvider.notifier).state = await fresh(savedTemperatureEntityConfigProvider);
    case 'rooms':
      ref.read(roomsProvider.notifier).state = await fresh(savedRoomsProvider);
    case 'house_screen' || 'house_scenes' || 'house_locks' || 'house_cameras':
      ref.read(houseConfigProvider.notifier).state = await fresh(savedHouseConfigProvider);
    case 'energy_entities':
      ref.read(energyEntityConfigProvider.notifier).state = await fresh(savedEnergyEntityConfigProvider);
    case 'individual_sensors':
      ref.read(individualSensorsProvider.notifier).state = await fresh(savedIndividualSensorsProvider);
    case 'ev_cars':
      ref.read(evCarsConfigProvider.notifier).state = await fresh(savedEvCarsConfigProvider);
  }
}
