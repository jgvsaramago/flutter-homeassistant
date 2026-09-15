import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ha_providers.dart';
import 'house_mode_store.dart';

final houseModeStoreProvider = Provider<HouseModeStore>((ref) => HouseModeStore(ref.watch(haWebSocketClientProvider)));

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `savedTemperatureEntityConfigProvider`.
final savedHouseModeConfigProvider = FutureProvider<HouseModeConfig>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(houseModeStoreProvider).read();
});

/// The config currently in use — set from [savedHouseModeConfigProvider] at
/// startup (see `settingsHydrationProvider`), then updated directly whenever
/// Settings saves a change, so the Homepage chip picks it up live without a
/// restart.
final houseModeConfigProvider = StateProvider<HouseModeConfig>((ref) => const HouseModeConfig());
