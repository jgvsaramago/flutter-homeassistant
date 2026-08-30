import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'energy_savings_store.dart';

final energySavingsStoreProvider = Provider<EnergySavingsStore>((ref) => EnergySavingsStore());

/// Month-to-date savings total, recomputed whenever [todaySavings] changes
/// (see [EnergySavingsStore] for what "month-to-date" means here). Each
/// distinct `todaySavings` value gets its own provider instance —
/// `autoDispose` drops the stale ones once nothing watches them anymore.
final energyMonthSavingsProvider = FutureProvider.autoDispose.family<double, double>((ref, todaySavings) {
  return ref.watch(energySavingsStoreProvider).recordToday(todaySavings);
});
