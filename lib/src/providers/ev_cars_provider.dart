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

/// The config currently in use — set from [savedEvCarsConfigProvider] at
/// startup (see `RootScreen`), then updated directly whenever Settings saves
/// a change, so the EV cards pick it up live without a restart.
final evCarsConfigProvider = StateProvider<EvCarsConfig>(
  (ref) => EvCarsConfig.defaults,
);

/// Identifies which of the Homepage's two fixed EV card slots a widget is
/// working with — the EV cards row, the EV sheet and its "stop charge"
/// state all key off this instead of a car name, since a name is editable
/// display copy while the slot itself is fixed.
enum CarSide { left, right }

extension EvCarsConfigSide on EvCarsConfig {
  EvCarConfig forSide(CarSide side) => side == CarSide.left ? left : right;
}

/// Mirrors the reference implementation's `chargeStopped` state: tapping
/// "Parar carga" in the EV sheet flips a car to the idle presentation for
/// the rest of this session, without touching whatever real entity reports
/// [EvCarConfig.chargingEntityId] (this app has no "stop charging" service
/// wired to any entity). Not persisted — same as the reference, where the
/// flag lives only in memory and resets on a fresh app launch, though it
/// does survive closing and reopening the sheet.
final evChargeStoppedProvider = StateProvider.family<bool, CarSide>(
  (ref, side) => false,
);
