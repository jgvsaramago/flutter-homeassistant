import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../theme/nocturne_theme.dart';

/// The counts [StatusBadgeRow] renders, nothing else — a Dart record, so
/// Riverpod's `select` can compare it structurally and only notify the row
/// when one of these actually changes, instead of on every entity update
/// anywhere in the (potentially thousands-strong) HA instance.
typedef _BadgeSummary = ({int notifications, int lightsOn, int windowsOpen, bool hasGate, bool gateOpen, bool acOn});

_BadgeSummary _summarize(Map<String, HaEntity> entities) {
  final values = entities.values;

  final notifications = values.where((e) => e.domain == 'persistent_notification').length;

  final lightsOn = values.where((e) => e.domain == 'light' && e.isOn).length;

  final windowsOpen = values.where((e) => e.domain == 'binary_sensor' && e.deviceClass == 'window' && e.isOn).length;

  final gates = values.where((e) => e.domain == 'cover' && e.deviceClass == 'garage');
  final gateOpen = gates.any((e) => e.state == 'open');
  final hasGate = gates.isNotEmpty;

  final acOn = values.any((e) => e.domain == 'climate' && e.state != 'off');

  return (notifications: notifications, lightsOn: lightsOn, windowsOpen: windowsOpen, hasGate: hasGate, gateOpen: gateOpen, acOn: acOn);
}

/// Section 2 of the Homepage: a row of status pills. Each pill is a live
/// aggregate over [entitiesProvider] by domain/device_class (not hardcoded
/// entity ids), so it works against any Home Assistant instance rather than
/// this household's specific devices.
class StatusBadgeRow extends ConsumerWidget {
  const StatusBadgeRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(entitiesProvider.select((async) => _summarize(async.value ?? const {})));
    final notifications = summary.notifications;
    final lightsOn = summary.lightsOn;
    final windowsOpen = summary.windowsOpen;
    final hasGate = summary.hasGate;
    final gateOpen = summary.gateOpen;
    final acOn = summary.acOn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 7,
      children: [
        _Badge(icon: Icons.notifications_none, label: '$notifications'),
        _Badge(
          icon: Icons.lightbulb_outline,
          label: '$lightsOn luz${lightsOn == 1 ? '' : 'es'}',
          tint: NocturneColors.amber,
        ),
        _Badge(
          icon: Icons.window_outlined,
          label: '$windowsOpen janela${windowsOpen == 1 ? '' : 's'}',
          tint: NocturneColors.blue,
        ),
        if (hasGate) _Badge(icon: Icons.garage_outlined, label: gateOpen ? 'Portão aberto' : 'Portão fechado'),
        _Badge(icon: Icons.ac_unit, label: acOn ? 'A/C ligado' : 'A/C desligado'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? NocturneColors.neutral500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(NocturneRadii.pill),
        border: tint == null ? Border.all(color: NocturneColors.neutral800) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint != null ? color : NocturneColors.neutral300),
          const SizedBox(width: 6),
          Text(
            label,
            softWrap: false,
            maxLines: 1,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: tint != null ? color : null),
          ),
        ],
      ),
    );
  }
}
