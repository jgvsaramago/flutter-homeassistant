import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ev_cars_store.dart';
import 'ha_providers.dart';

final evCarsStoreProvider = Provider<EvCarsStore>((ref) => EvCarsStore(ref.watch(haWebSocketClientProvider)));

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedEvCarsConfigProvider = FutureProvider<EvCarsConfig>((ref) async {
  await ref.watch(entitiesProvider.future);
  return ref.watch(evCarsStoreProvider).read();
});

/// The config currently in use — set from [savedEvCarsConfigProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final evCarsConfigProvider = StateProvider<EvCarsConfig>(
  (ref) => EvCarsConfig.defaults,
);
