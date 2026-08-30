import 'package:flutter/material.dart';

import '../../models/ha_entity.dart';
import 'climate_card.dart';
import 'cover_card.dart';
import 'info_card.dart';
import 'lock_card.dart';
import 'toggle_entity_card.dart';

/// Picks the right specific card widget for an entity's domain.
class EntityCard extends StatelessWidget {
  const EntityCard({super.key, required this.entity});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    switch (entity.domain) {
      case 'light':
      case 'switch':
      case 'fan':
        return ToggleEntityCard(entity: entity);
      case 'lock':
        return LockCard(entity: entity);
      case 'cover':
        return CoverCard(entity: entity);
      case 'climate':
        return ClimateCard(entity: entity);
      default:
        return InfoCard(entity: entity);
    }
  }
}
