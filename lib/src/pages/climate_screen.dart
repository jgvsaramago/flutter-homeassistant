import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ha_entity.dart';
import '../providers/ha_providers.dart';
import '../providers/rooms_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/climate/ac_unit_card.dart';
import '../widgets/climate/climate_zone_stats.dart';
import '../widgets/climate/shutter_card.dart';

bool _hasId(String? id) => id != null && id.trim().isNotEmpty;

/// A room counts as an AC unit on this page only when its `climateEntityId`
/// is actually a `climate.*` entity — a plain `switch.*` (still valid for
/// the Divisões room card's simpler on/off icon) has none of the
/// attributes (`hvac_modes`, target temperature, ...) this page's AC card
/// needs.
bool _isAcRoom(RoomEntry room) => _hasId(room.config.climateEntityId) && room.config.climateEntityId!.startsWith('climate.');

bool _isShutterRoom(RoomEntry room) => _hasId(room.config.coverEntityId);

/// Groups entity ids by domain and calls the service once per group — same
/// idiom `RoomsScreen`'s own bulk actions use, duplicated locally rather
/// than shared since this page's callers already know their domain is
/// fixed (`climate`/`cover`) and don't need the generic split-by-id-prefix
/// behavior.
Future<void> _callServiceGrouped(WidgetRef ref, String domain, String service, Iterable<String> entityIds) async {
  final ids = entityIds.toList();
  if (ids.isEmpty) return;
  final client = ref.read(haWebSocketClientProvider);
  await client.callService(domain, service, target: {'entity_id': ids});
}

String _joinPt(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items[0];
  if (items.length == 2) return '${items[0]} e ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
}

String _summary(List<FloorStat> floors) {
  if (floors.isEmpty) {
    return 'Nenhuma divisão configurada. Adicione divisões em Definições → Divisões.';
  }
  return '${_joinPt([for (final f in floors) '${f.label} a ${formatDegreeComma(f.avgTemp)}'])}.';
}

/// The "Clima" tab — Home Assistant `climate.*`/`cover.*` entities wired
/// per room via Definições → Divisões (see `RoomConfig.climateEntityId`/
/// `coverEntityId`), rendered as the reference design's Climatização page:
/// per-floor stat tiles, one AC card per configured unit, and one shutter
/// card per configured cover. Rooms are HA areas (see `RoomEntry`), so both
/// the floor grouping and each stat tile's temperature/humidity come
/// straight from HA's own area/floor registries — nothing here is entered
/// a second time. Unlike every other tab, this one is allowed to scroll —
/// see `PROMPT-04-climate-page.md` Part B.
class ClimateScreen extends ConsumerWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomEntriesProvider);
    final entities = ref.watch(entitiesProvider).value ?? const <String, HaEntity>{};

    final acRooms = rooms.where(_isAcRoom).toList();
    final shutterRooms = rooms.where(_isShutterRoom).toList();
    final floorStats = computeFloorStats(rooms, entities);

    final acOnIds = [for (final r in acRooms) if (_isAcOn(entities[r.config.climateEntityId])) r.config.climateEntityId!];
    final shuttersNotOpenIds = [for (final r in shutterRooms) if (_coverPos(entities[r.config.coverEntityId]) < 100) r.config.coverEntityId!];
    final shuttersNotClosedIds = [for (final r in shutterRooms) if (_coverPos(entities[r.config.coverEntityId]) > 0) r.config.coverEntityId!];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Climatização', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(_summary(floorStats), style: TextStyle(fontSize: 19, color: NocturneColors.neutral400, height: 1.45)),
                if (floorStats.isNotEmpty) ...[const SizedBox(height: 16), _StatTileRow(floors: floorStats)],
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'AR CONDICIONADO',
                  trailing: _Pill(
                    label: 'Desligar todos',
                    enabled: acOnIds.isNotEmpty,
                    onTap: () => _callServiceGrouped(ref, 'climate', 'turn_off', acOnIds),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (acRooms.isEmpty)
          SliverToBoxAdapter(child: _EmptyHint(text: 'Nenhum ar condicionado configurado.\nAdicione uma entidade climate.* a uma divisão em Definições → Divisões.'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            sliver: SliverList.separated(
              itemCount: acRooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => AcUnitCard(roomName: acRooms[index].name, entity: entities[acRooms[index].config.climateEntityId]),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: _SectionHeader(
              title: 'ESTORES',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Pill(label: 'Abrir todos', enabled: true, onTap: () => _callServiceGrouped(ref, 'cover', 'open_cover', shuttersNotOpenIds)),
                  const SizedBox(width: 10),
                  _Pill(label: 'Fechar todos', enabled: true, onTap: () => _callServiceGrouped(ref, 'cover', 'close_cover', shuttersNotClosedIds)),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (shutterRooms.isEmpty)
          SliverToBoxAdapter(child: _EmptyHint(text: 'Nenhum estore configurado.\nAdicione uma entidade cover.* a uma divisão em Definições → Divisões.'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverGrid(
              // A fixed main-axis extent (rather than an aspect ratio) so
              // the card's fixed-height content (the 112px window thumbnail
              // and, while moving, the 112px stop button) always has
              // comfortable room regardless of how wide a column ends up.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 168),
              delegate: SliverChildBuilderDelegate(
                (context, index) => ShutterCard(roomName: shutterRooms[index].name, entity: entities[shutterRooms[index].config.coverEntityId]),
                childCount: shutterRooms.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

int _coverPos(HaEntity? entity) {
  if (entity == null || entity.isUnavailable) return 0;
  final raw = entity.attributes['current_position'];
  if (raw is num) return raw.round().clamp(0, 100);
  return entity.state == 'closed' ? 0 : 100;
}

bool _isAcOn(HaEntity? entity) => entity != null && !entity.isUnavailable && entity.state != 'off';

/// A wrapping row of temp/humidity tile pairs, one pair per floor — 4 per
/// row (matching the reference design's fixed 4-tile layout for the common
/// 2-floor case), wrapping onto further rows for a household with more
/// floors than that. [LayoutBuilder] sizes each tile to a quarter of the
/// available width since [Wrap] itself has no notion of "N equal columns".
class _StatTileRow extends StatelessWidget {
  const _StatTileRow({required this.floors});

  final List<FloorStat> floors;

  static const _humidityColor = Color(0xFF2F7CC4);
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - _gap * 3) / 4;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final floor in floors) ...[
              SizedBox(width: tileWidth, child: _StatTile(label: 'MÉDIA ${floor.label.toUpperCase()}', value: formatDegreeComma(floor.avgTemp))),
              SizedBox(width: tileWidth, child: _StatTile(label: 'HUMIDADE ${floor.label.toUpperCase()}', value: formatPercent(floor.avgHumidity), color: _humidityColor)),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 13, letterSpacing: 1.1, color: NocturneColors.neutral500), maxLines: 2),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: color ?? NocturneColors.text)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.5, color: NocturneColors.accent))),
        trailing,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NocturneColors.neutral900,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(label, style: TextStyle(fontSize: 16, color: enabled ? NocturneColors.neutral300 : NocturneColors.neutral600)),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: TextStyle(fontSize: 15, color: NocturneColors.neutral500, height: 1.4)),
      ),
    );
  }
}
