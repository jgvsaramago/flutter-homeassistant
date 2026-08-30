import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ha_providers.dart';
import '../widgets/entity_grid_slivers.dart';

class ClimateScreen extends ConsumerWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final climateEntities = entities.values.where((e) => e.domain == 'climate').toList()
      ..sort((a, b) => a.friendlyName.toLowerCase().compareTo(b.friendlyName.toLowerCase()));

    return CustomScrollView(
      slivers: climateEntities.isEmpty
          ? const [EmptySectionSliver(icon: Icons.thermostat_outlined, message: 'No climate entities found.')]
          : [
              ...entityGridSlivers(context, title: 'Climate', entities: climateEntities),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
    );
  }
}
