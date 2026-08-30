import 'package:flutter/material.dart';

import '../../models/ha_entity.dart';
import '../../utils/domain_icons.dart';
import 'card_shell.dart';

/// Read-only card for domains we don't offer controls for yet: `sensor`,
/// `binary_sensor`, `person`, `weather`, and any unrecognized domain.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CardShell(
      icon: iconForEntity(entity),
      iconColor: entity.isUnavailable
          ? theme.colorScheme.onSurfaceVariant
          : (entity.domain == 'binary_sensor' && entity.isOn ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      title: entity.friendlyName,
      subtitle: null,
      child: Text(entity.displayState, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
    );
  }
}
