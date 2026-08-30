import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import 'card_shell.dart';

class CoverCard extends ConsumerWidget {
  const CoverCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final open = entity.state == 'open';
    final unavailable = entity.isUnavailable;

    Future<void> call(String service) async {
      final client = ref.read(haWebSocketClientProvider);
      await client.callService('cover', service, target: {'entity_id': entity.entityId});
    }

    return CardShell(
      icon: open ? Icons.garage_outlined : Icons.garage,
      iconColor: open ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      title: entity.friendlyName,
      subtitle: unavailable ? 'Unavailable' : entity.state,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Open',
            onPressed: unavailable ? null : () => call('open_cover'),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Stop',
            onPressed: unavailable ? null : () => call('stop_cover'),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Close',
            onPressed: unavailable ? null : () => call('close_cover'),
          ),
        ],
      ),
    );
  }
}
