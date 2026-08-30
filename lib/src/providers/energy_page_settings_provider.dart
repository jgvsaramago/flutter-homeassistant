import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'energy_page_settings_store.dart';
import 'ha_providers.dart';

final energyPageSettingsStoreProvider = Provider<EnergyPageSettingsStore>(
  (ref) => EnergyPageSettingsStore(ref.watch(haWebSocketClientProvider)),
);

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedEnergyPageConfigProvider = FutureProvider<EnergyPageConfig>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(energyPageSettingsStoreProvider).read();
});

/// The config currently in use — set from [savedEnergyPageConfigProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings saves
/// a change, so the Energia page picks it up live without a restart.
final energyPageConfigProvider = StateProvider<EnergyPageConfig>((ref) => const EnergyPageConfig());
