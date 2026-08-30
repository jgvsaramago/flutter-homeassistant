import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import 'card_shell.dart';

/// Card for `climate` entities: shows current/target temperature and lets
/// the user nudge the target up/down. HVAC mode switching is left to the HA
/// app itself to keep this card simple.
class ClimateCard extends ConsumerWidget {
  const ClimateCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unavailable = entity.isUnavailable;
    final current = entity.attributes['current_temperature'];
    final target = entity.attributes['temperature'];
    final step = (entity.attributes['target_temp_step'] as num?)?.toDouble() ?? 0.5;

    Future<void> nudge(double delta) async {
      if (target is! num) return;
      final client = ref.read(haWebSocketClientProvider);
      await client.callService(
        'climate',
        'set_temperature',
        serviceData: {'temperature': target + delta},
        target: {'entity_id': entity.entityId},
      );
    }

    return CardShell(
      icon: Icons.thermostat,
      iconColor: entity.state == 'off' ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
      title: entity.friendlyName,
      subtitle: unavailable
          ? 'Unavailable'
          : 'Mode: ${entity.state}${current != null ? ' • Now $current°' : ''}',
      child: target is num
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: unavailable ? null : () => nudge(-step),
                ),
                Text('$target°', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: unavailable ? null : () => nudge(step),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
