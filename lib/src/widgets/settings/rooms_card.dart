import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_area.dart';
import '../../models/ha_floor.dart';
import '../../providers/ha_providers.dart';
import '../../providers/rooms_provider.dart';
import '../../providers/rooms_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import 'settings_save_controller.dart';

/// One row being edited — always backed by a real [HaArea] (the room's
/// identity, name and floor all come from there, never typed here); only
/// this app's own entity mapping is mutable. A synthetic identity isn't
/// needed the way `CalendarEntitiesCard`'s `_DraftEntry` needs one across
/// add/remove — areas neither get added nor removed from this screen, only
/// configured, so `area.areaId` itself is already a stable [Key].
class _RoomDraftEntry {
  _RoomDraftEntry({
    required this.area,
    required this.floor,
    required this.secondaryEntityId,
    required this.lightEntityId,
    required this.windowEntityId,
    required this.climateEntityId,
    required this.speakerEntityId,
    required this.coverEntityId,
    required this.expanded,
  });

  factory _RoomDraftEntry.from(HaArea area, HaFloor? floor, RoomConfig? saved) => _RoomDraftEntry(
    area: area,
    floor: floor,
    secondaryEntityId: saved?.secondaryEntityId ?? '',
    lightEntityId: saved?.lightEntityId ?? '',
    windowEntityId: saved?.windowEntityId ?? '',
    climateEntityId: saved?.climateEntityId ?? '',
    speakerEntityId: saved?.speakerEntityId ?? '',
    coverEntityId: saved?.coverEntityId ?? '',
    expanded: false,
  );

  final HaArea area;
  final HaFloor? floor;
  String secondaryEntityId;
  String lightEntityId;
  String windowEntityId;
  String climateEntityId;
  String speakerEntityId;
  String coverEntityId;
  bool expanded;

  /// How many of the 6 optional entity fields are filled in — shown as a
  /// quick summary while the row is collapsed, and also what decides
  /// whether this area is saved as a divisão at all (see `_save`): an HA
  /// instance with dozens of areas shouldn't turn into dozens of empty
  /// Divisões cards just because this screen lists every one of them.
  int get configuredEntityCount => [
    secondaryEntityId,
    lightEntityId,
    windowEntityId,
    climateEntityId,
    speakerEntityId,
    coverEntityId,
  ].where((v) => v.trim().isNotEmpty).length;

  RoomConfig toConfig() => RoomConfig(
    areaId: area.areaId,
    secondaryEntityId: secondaryEntityId,
    lightEntityId: lightEntityId,
    windowEntityId: windowEntityId,
    climateEntityId: climateEntityId,
    speakerEntityId: speakerEntityId,
    coverEntityId: coverEntityId,
  );
}

int _floorSortLevel(HaFloor? floor) => floor?.level ?? (1 << 30);

/// Settings section letting the user wire each HA area's devices into the
/// Divisões/Climatização pages. Unlike before this mirrored HA's own Areas
/// & Zones (see `RoomConfig`'s own doc), there's no "add"/"remove"/reorder
/// here — the room list *is* the area list, already ordered (by floor,
/// then name) and named by HA itself. Temperature and humidity aren't
/// configured here either: they come from each area's own sensor picks in
/// HA's Areas & Zones settings.
class RoomsCard extends ConsumerStatefulWidget {
  const RoomsCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<RoomsCard> createState() => _RoomsCardState();
}

class _RoomsCardState extends ConsumerState<RoomsCard> {
  late List<_RoomDraftEntry> _draft;

  @override
  void initState() {
    super.initState();
    final areas = [...ref.read(areasProvider)]..sort((a, b) {
      final byFloor = _floorSortLevel(_floorFor(a)).compareTo(_floorSortLevel(_floorFor(b)));
      return byFloor != 0 ? byFloor : a.name.compareTo(b.name);
    });
    final savedByAreaId = {for (final r in ref.read(roomsProvider)) r.areaId: r};
    _draft = [for (final area in areas) _RoomDraftEntry.from(area, _floorFor(area), savedByAreaId[area.areaId])];
    widget.saveController?.bind(_save);
  }

  HaFloor? _floorFor(HaArea area) {
    if (area.floorId == null) return null;
    for (final floor in ref.read(floorsProvider)) {
      if (floor.floorId == area.floorId) return floor;
    }
    return null;
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  void _updateRoom(String areaId, void Function(_RoomDraftEntry entry) apply) {
    setState(() {
      apply(_draft.firstWhere((e) => e.area.areaId == areaId));
      _setSaved(false);
    });
  }

  Future<void> _save() async {
    final rooms = [for (final e in _draft) if (e.configuredEntityCount > 0) e.toConfig()];
    try {
      await ref.read(roomsStoreProvider).save(rooms);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(roomsProvider.notifier).state = rooms;
    if (!mounted) return;
    _setSaved(true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_outlined, size: 20, color: NocturneColors.accent),
                const SizedBox(width: 8),
                Text('DIVISÕES', style: NocturneText.cardKicker),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Uma linha por área da tua Home Assistant — nome, piso, temperatura e humidade vêm sempre de lá. '
              'Escolhe aqui só as restantes entidades de cada área; uma área sem nenhuma fica de fora das Divisões e da Climatização.',
              style: NocturneText.body,
            ),
            const SizedBox(height: 18),
            if (_draft.isEmpty)
              Text(
                'Nenhuma área encontrada na Home Assistant. Cria áreas em Definições → Áreas e Zonas na tua instância HA.',
                style: NocturneText.body,
              )
            else
              for (final entry in _draft) _RoomRow(key: ValueKey(entry.area.areaId), entry: entry, onUpdate: _updateRoom),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({super.key, required this.entry, required this.onUpdate});

  final _RoomDraftEntry entry;
  final void Function(String areaId, void Function(_RoomDraftEntry entry) apply) onUpdate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => onUpdate(entry.area.areaId, (e) => e.expanded = !e.expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.area.name,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: NocturneColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(entry.floor?.name ?? 'Sem piso', style: NocturneText.caption),
                      ],
                    ),
                  ),
                  Icon(entry.expanded ? Icons.expand_less : Icons.expand_more, color: NocturneColors.neutral500),
                ],
              ),
            ),
            if (!entry.expanded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  entry.configuredEntityCount == 0 ? 'Nenhuma entidade configurada' : '${entry.configuredEntityCount} de 6 entidades configuradas',
                  style: NocturneText.caption,
                ),
              ),
            ],
            if (entry.expanded) ...[
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Sensor secundário (opcional)',
                hint: 'sensor.quarto_co2 ou lock.quarto',
                initialValue: entry.secondaryEntityId,
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.secondaryEntityId = v),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'CO₂ ou fechadura mostram uma frase; qualquer outro sensor mostra o valor tal e qual. Sem isto, mostra a posição dos estores (se configurados).',
                  style: NocturneText.caption,
                ),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Luz',
                hint: 'light.quarto ou switch.quarto',
                initialValue: entry.lightEntityId,
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.lightEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Janela',
                hint: 'binary_sensor.quarto_window',
                initialValue: entry.windowEntityId,
                domainFilter: 'binary_sensor',
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.windowEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Ar condicionado',
                hint: 'climate.quarto ou switch.quarto_ac',
                initialValue: entry.climateEntityId,
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.climateEntityId = v),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'Uma entidade climate.* aqui também gera o cartão de AC desta divisão na página Climatização.',
                  style: NocturneText.caption,
                ),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Altifalante',
                hint: 'media_player.quarto',
                initialValue: entry.speakerEntityId,
                domainFilter: 'media_player',
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.speakerEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Estores',
                hint: 'cover.quarto_estores',
                initialValue: entry.coverEntityId,
                domainFilter: 'cover',
                onChanged: (v) => onUpdate(entry.area.areaId, (e) => e.coverEntityId = v),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('Também gera o cartão de estores desta divisão na página Climatização.', style: NocturneText.caption),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
