import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import 'card_shell.dart';

class LockCard extends ConsumerWidget {
  const LockCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locked = entity.state == 'locked';
    final unavailable = entity.isUnavailable;

    Future<void> setLocked(bool value) async {
      final client = ref.read(haWebSocketClientProvider);
      await client.callService(
        'lock',
        value ? 'lock' : 'unlock',
        target: {'entity_id': entity.entityId},
      );
    }

    return CardShell(
      icon: locked ? Icons.lock : Icons.lock_open,
      iconColor: locked ? theme.colorScheme.primary : theme.colorScheme.error,
      title: entity.friendlyName,
      subtitle: unavailable ? 'Unavailable' : (locked ? 'Locked' : 'Unlocked'),
      onTap: unavailable ? null : () => setLocked(!locked),
      child: IconButton(
        icon: Icon(locked ? Icons.lock_open : Icons.lock),
        tooltip: locked ? 'Unlock' : 'Lock',
        onPressed: unavailable ? null : () => setLocked(!locked),
      ),
    );
  }
}
