import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ha_entity.dart';
import '../providers/ha_providers.dart';
import '../providers/rooms_provider.dart';
import '../providers/rooms_store.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/entity_grid_slivers.dart';
import '../widgets/rooms/room_card.dart';
import '../widgets/rooms/room_view_model.dart';

bool _hasId(String? id) => id != null && id.trim().isNotEmpty;

/// The two bulk actions' current targets/availability, derived fresh from
/// live entity state every build — never a locally-tracked "did I already
/// do this" flag, unlike the reference's one-way `lightsOff` toggle. A
/// light or cover left on by some other means (a physical switch, an
/// automation) is exactly the case a bulk action should still catch.
typedef _BulkActions = ({Set<String> lightIds, bool anyLightOn, Set<String> coverIds, bool anyCoverOpen});

_BulkActions _resolveBulkActions(List<RoomConfig> rooms, Map<String, HaEntity> entities) {
  final lightIds = <String>{for (final r in rooms) if (_hasId(r.lightEntityId)) r.lightEntityId!};
  final anyLightOn = lightIds.any((id) {
    final e = entities[id];
    return e != null && !e.isUnavailable && e.isOn;
  });
  final coverIds = <String>{for (final r in rooms) if (_hasId(r.coverEntityId)) r.coverEntityId!};
  final anyCoverOpen = coverIds.any((id) => entities[id]?.state != 'closed');
  return (lightIds: lightIds, anyLightOn: anyLightOn, coverIds: coverIds, anyCoverOpen: anyCoverOpen);
}

/// Groups entity ids by domain and calls the service once per group — a
/// service call is domain-scoped (`light.turn_off` only accepts `light.*`),
/// so a light room wired to a `switch.*` entity needs its own call.
Future<void> _callServiceGrouped(WidgetRef ref, String service, Set<String> entityIds, {String? domainOverride}) async {
  if (entityIds.isEmpty) return;
  final client = ref.read(haWebSocketClientProvider);
  final byDomain = <String, List<String>>{};
  for (final id in entityIds) {
    byDomain.putIfAbsent(domainOverride ?? id.split('.').first, () => []).add(id);
  }
  for (final entry in byDomain.entries) {
    await client.callService(entry.key, service, target: {'entity_id': entry.value});
  }
}

String _joinPt(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items[0];
  if (items.length == 2) return '${items[0]} e ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
}

String _summary(int roomCount, int lightsOn, int windowsOpen, int acOn) {
  if (roomCount == 0) return 'Nenhuma divisão configurada. Adicione divisões em Definições → Divisões.';
  final roomsPart = '$roomCount ${roomCount == 1 ? 'divisão monitorizada' : 'divisões monitorizadas'}.';
  final bits = <String>[
    if (lightsOn > 0) '$lightsOn ${lightsOn == 1 ? 'luz acesa' : 'luzes acesas'}',
    if (windowsOpen > 0) '$windowsOpen ${windowsOpen == 1 ? 'janela aberta' : 'janelas abertas'}',
    if (acOn > 0) '$acOn ${acOn == 1 ? 'ar condicionado ligado' : 'ares condicionados ligados'}',
  ];
  final statusPart = bits.isEmpty ? 'Tudo desligado.' : '${_joinPt(bits)}.';
  return '$roomsPart $statusPart';
}

/// The "Divisões" tab: a written summary, 4 live counters, two bulk
/// actions, and a card per configured room. Fully driven by
/// Settings → Divisões — this app has no rooms baked in, so an empty
/// configuration shows a prompt to go configure some rather than any
/// auto-discovered fallback.
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final entities = ref.watch(entitiesProvider).value ?? const {};

    final views = [for (final room in rooms) buildRoomView(room, entities)];
    final lightsOn = views.where((v) => v.lightOn).length;
    final windowsOpen = views.where((v) => v.windowOpen).length;
    final acOn = views.where((v) => v.acOn).length;
    final temps = [
      for (final room in rooms)
        if (_hasId(room.temperatureEntityId)) entities[room.temperatureEntityId],
    ].whereType<HaEntity>().where((e) => !e.isUnavailable).map((e) => double.tryParse(e.state)).whereType<double>().toList();
    final avgTemp = temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;

    final bulk = _resolveBulkActions(rooms, entities);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Divisões', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                  _summary(rooms.length, lightsOn, windowsOpen, acOn),
                  style: const TextStyle(fontSize: 19, color: NocturneColors.neutral400, height: 1.45),
                ),
                const SizedBox(height: 16),
                _CountersRow(lights: lightsOn, windows: windowsOpen, ac: acOn, avgTemp: avgTemp),
                const SizedBox(height: 12),
                _ActionsRow(bulk: bulk),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (rooms.isEmpty)
          const EmptySectionSliver(icon: Icons.grid_view_outlined, message: 'Nenhuma divisão configurada.\nAdicione divisões em Definições → Divisões.')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 336 / 210,
              ),
              delegate: SliverChildBuilderDelegate((context, index) => RoomCard(view: views[index]), childCount: views.length),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

class _CountersRow extends StatelessWidget {
  const _CountersRow({required this.lights, required this.windows, required this.ac, required this.avgTemp});

  final int lights;
  final int windows;
  final int ac;
  final double? avgTemp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _CounterTile(label: 'LUZES', value: '$lights', color: NocturneColors.amber)),
        const SizedBox(width: 10),
        Expanded(child: _CounterTile(label: 'JANELAS', value: '$windows', color: NocturneColors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _CounterTile(label: 'AC', value: '$ac', color: NocturneColors.green)),
        const SizedBox(width: 10),
        Expanded(child: _CounterTile(label: 'MÉDIA', value: '${formatTempComma(avgTemp)}°', color: NocturneColors.text)),
      ],
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, letterSpacing: 1.1, color: NocturneColors.neutral500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({required this.bulk});

  final _BulkActions bulk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightsEnabled = bulk.anyLightOn;
    final coversConfigured = bulk.coverIds.isNotEmpty;
    final closing = bulk.anyCoverOpen;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.lightbulb_outline,
            label: lightsEnabled ? 'Apagar todas as luzes' : 'Luzes apagadas',
            enabled: lightsEnabled,
            onTap: () => _callServiceGrouped(ref, 'turn_off', bulk.lightIds),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.blinds,
            label: !coversConfigured ? 'Sem estores configurados' : (closing ? 'Fechar todos os estores' : 'Abrir todos os estores'),
            enabled: coversConfigured,
            onTap: () => _callServiceGrouped(ref, closing ? 'close_cover' : 'open_cover', bulk.coverIds, domainOverride: 'cover'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.enabled, required this.onTap});

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? NocturneColors.accent : NocturneColors.neutral600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: enabled ? NocturneColors.accent : NocturneColors.neutral800),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 11),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 18, fontWeight: enabled ? FontWeight.w500 : FontWeight.w400, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
