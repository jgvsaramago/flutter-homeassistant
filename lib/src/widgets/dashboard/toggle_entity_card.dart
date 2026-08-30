import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../utils/domain_icons.dart';
import 'card_shell.dart';

/// A card for domains that are a simple on/off toggle: `light`, `switch`,
/// `fan`.
class ToggleEntityCard extends ConsumerWidget {
  const ToggleEntityCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final on = entity.isOn;
    final unavailable = entity.isUnavailable;

    Future<void> toggle(bool value) async {
      final client = ref.read(haWebSocketClientProvider);
      await client.callService(
        entity.domain,
        value ? 'turn_on' : 'turn_off',
        target: {'entity_id': entity.entityId},
      );
    }

    return CardShell(
      icon: iconForEntity(entity),
      iconColor: on ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      title: entity.friendlyName,
      subtitle: unavailable ? 'Unavailable' : (on ? 'On' : 'Off'),
      onTap: unavailable ? null : () => toggle(!on),
      child: Switch(value: on, onChanged: unavailable ? null : toggle),
    );
  }
}
