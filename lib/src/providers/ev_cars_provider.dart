import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ev_cars_store.dart';
import 'ha_providers.dart';

final carsStoreProvider = Provider<CarsStore>((ref) => CarsStore(ref.watch(haWebSocketClientProvider)));

/// Config persisted from a previous session, read once at startup — waits
/// for the HA connection first, same idiom as `areaByEntityIdProvider`.
final savedCarsConfigProvider = FutureProvider<CarsConfig>((ref) async {
  await haReady(ref);
  return ref.watch(carsStoreProvider).read();
});

/// The config currently in use — set from [savedCarsConfigProvider] at startup (see
/// `settingsHydrationProvider`). It's edited in the HA sidebar panel
/// (Flutter Dashboard), not in the app.
final carsConfigProvider = StateProvider<CarsConfig>((ref) => CarsConfig.empty);
