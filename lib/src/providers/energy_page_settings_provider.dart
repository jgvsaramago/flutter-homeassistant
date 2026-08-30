import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'energy_page_settings_store.dart';

final energyPageSettingsStoreProvider = Provider<EnergyPageSettingsStore>((ref) => EnergyPageSettingsStore());

/// Config persisted from a previous session, read once at startup.
final savedEnergyPageConfigProvider = FutureProvider<EnergyPageConfig>((ref) {
  return ref.watch(energyPageSettingsStoreProvider).read();
});

/// The config currently in use — set from [savedEnergyPageConfigProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings saves
/// a change, so the Energia page picks it up live without a restart.
final energyPageConfigProvider = StateProvider<EnergyPageConfig>((ref) => const EnergyPageConfig());
