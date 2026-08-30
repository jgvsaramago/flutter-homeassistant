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

/// The config currently in use — set from [savedEnergyEntityConfigProvider]
/// at startup (see `RootScreen`), then updated directly whenever Settings
/// saves a change, so the energy card picks it up live without a restart.
final energyEntityConfigProvider = StateProvider<EnergyEntityConfig>((ref) => const EnergyEntityConfig());
