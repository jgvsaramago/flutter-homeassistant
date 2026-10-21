import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'temperature_entities_store.dart';

final temperatureEntitiesStoreProvider = Provider<TemperatureEntitiesStore>(
  (ref) => TemperatureEntitiesStore(ref.watch(haWebSocketClientProvider)),
);

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedTemperatureEntityConfigProvider = FutureProvider<TemperatureEntityConfig>((ref) async {
  await haReady(ref);
  return ref.watch(temperatureEntitiesStoreProvider).read();
});

/// The config currently in use — set from [savedTemperatureEntityConfigProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final temperatureEntityConfigProvider = StateProvider<TemperatureEntityConfig>((ref) => const TemperatureEntityConfig());
