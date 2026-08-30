import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'temperature_entities_store.dart';

final temperatureEntitiesStoreProvider = Provider<TemperatureEntitiesStore>((ref) => TemperatureEntitiesStore());

/// Config persisted from a previous session, read once at startup.
final savedTemperatureEntityConfigProvider = FutureProvider<TemperatureEntityConfig>((ref) {
  return ref.watch(temperatureEntitiesStoreProvider).read();
});

/// The config currently in use — set from [savedTemperatureEntityConfigProvider]
/// at startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the Temperatures sheet picks it up live without a
/// restart.
final temperatureEntityConfigProvider = StateProvider<TemperatureEntityConfig>((ref) => const TemperatureEntityConfig());
