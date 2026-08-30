import 'package:flutter/material.dart';

import 'dashboard/entity_card.dart';
import '../models/ha_entity.dart';

/// A section header + responsive grid of [EntityCard]s, as a pair of
/// slivers. Shared by every screen that lists entities in groups (by
/// domain, by area, ...).
List<Widget> entityGridSlivers(BuildContext context, {required String title, required List<HaEntity> entities}) {
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 150,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) => EntityCard(entity: entities[index]), childCount: entities.length),
      ),
    ),
  ];
}

/// Centered placeholder for a screen with nothing to show, sized to fill
/// the remaining scroll viewport.
class EmptySectionSliver extends StatelessWidget {
  const EmptySectionSliver({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(message, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
