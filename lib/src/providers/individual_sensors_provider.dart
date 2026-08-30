import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'individual_sensors_store.dart';

final individualSensorsStoreProvider = Provider<IndividualSensorsStore>((ref) => IndividualSensorsStore());

/// Config persisted from a previous session, read once at startup.
final savedIndividualSensorsProvider = FutureProvider<List<IndividualSensorConfig>>((ref) {
  return ref.watch(individualSensorsStoreProvider).read();
});

/// The individual-sensor list currently in use — set from
/// [savedIndividualSensorsProvider] at startup (see `RootScreen`), then
/// updated directly whenever Settings saves a change, so the energy card's
/// device nodes pick it up live without a restart. Starts empty, same as
/// `calendarEntriesProvider` — this app has no household-specific circuits
/// baked in, so the card shows no device nodes until the user adds some.
final individualSensorsProvider = StateProvider<List<IndividualSensorConfig>>((ref) => const []);
