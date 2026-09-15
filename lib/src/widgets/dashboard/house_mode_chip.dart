import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import '../../providers/house_mode_provider.dart';
import '../../theme/nocturne_theme.dart';

/// House-mode selector shown in the Homepage header, next to the greeting —
/// a tappable pill mirroring the configured `input_select` entity's current
/// option, mirrors that entity's own list of options, and picking one calls
/// `select.select_option`. Hides itself entirely when no entity is
/// configured (see Definições → Modo da Casa) or the entity isn't found.
class HouseModeChip extends ConsumerWidget {
  const HouseModeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(houseModeConfigProvider);
    if (config.isEmpty) return const SizedBox.shrink();

    final entity = ref.watch(entitiesProvider).value?[config.entityId];
    if (entity == null) return const SizedBox.shrink();

    final options = (entity.attributes['options'] as List?)?.whereType<String>().toList() ?? const [];

    Future<void> select(String option) async {
      await ref.read(haWebSocketClientProvider).callService(
        'select',
        'select_option',
        serviceData: {'option': option},
        target: {'entity_id': entity.entityId},
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: PopupMenuButton<String>(
        enabled: options.isNotEmpty,
        onSelected: select,
        itemBuilder: (context) => [for (final option in options) PopupMenuItem(value: option, child: Text(option))],
        color: NocturneColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadii.chip)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.house_outlined, size: 18, color: NocturneColors.accent),
              const SizedBox(width: 8),
              Text(entity.state, style: NocturneText.itemTitle.copyWith(fontSize: 16)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: NocturneColors.neutral500),
            ],
          ),
        ),
      ),
    );
  }
}
