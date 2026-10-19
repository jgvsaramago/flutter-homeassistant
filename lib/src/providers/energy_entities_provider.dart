import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'energy_entities_store.dart';
import 'ha_providers.dart';

final energyEntitiesStoreProvider = Provider<EnergyEntitiesStore>(
  (ref) => EnergyEntitiesStore(ref.watch(haWebSocketClientProvider)),
);

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedEnergyEntityConfigProvider = FutureProvider<EnergyEntityConfig>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(energyEntitiesStoreProvider).read();
});

/// The config currently in use — set from [savedEnergyEntityConfigProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final energyEntityConfigProvider = StateProvider<EnergyEntityConfig>((ref) => const EnergyEntityConfig());
