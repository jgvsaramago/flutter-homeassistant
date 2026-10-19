import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'individual_sensors_store.dart';

final individualSensorsStoreProvider = Provider<IndividualSensorsStore>(
  (ref) => IndividualSensorsStore(ref.watch(haWebSocketClientProvider)),
);

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedIndividualSensorsProvider = FutureProvider<List<IndividualSensorConfig>>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(individualSensorsStoreProvider).read();
});

/// The config currently in use — set from [savedIndividualSensorsProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final individualSensorsProvider = StateProvider<List<IndividualSensorConfig>>((ref) => const []);
