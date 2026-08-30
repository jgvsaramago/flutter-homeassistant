import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'temperature_entities_store.dart';

final temperatureEntitiesStoreProvider = Provider<TemperatureEntitiesStore>(
  (ref) => TemperatureEntitiesStore(ref.watch(haWebSocketClientProvider)),
);

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedTemperatureEntityConfigProvider = FutureProvider<TemperatureEntityConfig>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(temperatureEntitiesStoreProvider).read();
});

/// The config currently in use — set from [savedTemperatureEntityConfigProvider]
/// at startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the Temperatures sheet picks it up live without a
/// restart.
final temperatureEntityConfigProvider = StateProvider<TemperatureEntityConfig>((ref) => const TemperatureEntityConfig());
