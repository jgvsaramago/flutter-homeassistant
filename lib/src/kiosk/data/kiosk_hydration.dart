import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import 'chores_data.dart';
import 'family_data.dart';
import 'house_config.dart';
import 'meals_data.dart';
import 'todo_data.dart';

/// Loads the redesign's own config and data from HA once connected — same
/// shape and reasoning as `settingsHydrationProvider` (each read is
/// independently try/caught, so one missing key never blocks the screen).
final kioskHydrationProvider = FutureProvider<void>((ref) async {
  await ref.watch(entitiesProvider.future);

  try {
    final family = await ref.read(savedFamilyProvider.future);
    if (family.isNotEmpty) ref.read(familyConfigProvider.notifier).state = family;
  } catch (_) {
    // Falls back to HA's person entities — see familyMembersProvider.
  }
  try {
    ref.read(houseConfigProvider.notifier).state = await ref.read(savedHouseConfigProvider.future);
  } catch (_) {
    // Casa sections fall back to auto-detected entities.
  }
  try {
    final icons = await ref.read(savedTodoListIconsProvider.future);
    if (icons.isNotEmpty) ref.read(todoListIconsProvider.notifier).state = icons;
  } catch (_) {
    // Icons are guessed from list names.
  }
  try {
    await ref.read(mealPlanProvider.notifier).load();
  } catch (_) {
    // An empty plan — every cell offers "Planear".
  }
  try {
    await ref.read(choresProvider.notifier).load();
  } catch (_) {
    // No tasks yet.
  }
});
