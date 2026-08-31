import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/rooms_provider.dart';
import '../../providers/rooms_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import '../keyboard_text_field.dart';
import 'settings_save_controller.dart';

/// One room being edited — a synthetic [id] (not the room's name, which is
/// mutable and briefly empty/duplicated while typing) gives each row a
/// stable [Key] across add/remove, so each `EntityIdField`'s own internal
/// `TextEditingController` stays attached to the right row. Same pattern as
/// `CalendarEntitiesCard`'s `_DraftEntry`.
class _RoomDraftEntry {
  _RoomDraftEntry({
    required this.id,
    required this.name,
    required this.temperatureEntityId,
    required this.secondaryEntityId,
    required this.lightEntityId,
    required this.windowEntityId,
    required this.climateEntityId,
    required this.speakerEntityId,
    required this.coverEntityId,
    required this.expanded,
  });

  factory _RoomDraftEntry.blank(int id) => _RoomDraftEntry(
    id: id,
    name: '',
    temperatureEntityId: '',
    secondaryEntityId: '',
    lightEntityId: '',
    windowEntityId: '',
    climateEntityId: '',
    speakerEntityId: '',
    coverEntityId: '',
    // A freshly-added row has nothing to hide yet and the user is about to
    // fill it in — open by default. An already-configured room loaded from
    // storage (see .from below) starts collapsed instead, so a long room
    // list doesn't open as a wall of fields.
    expanded: true,
  );

  factory _RoomDraftEntry.from(int id, RoomConfig room) => _RoomDraftEntry(
    id: id,
    name: room.name,
    temperatureEntityId: room.temperatureEntityId ?? '',
    secondaryEntityId: room.secondaryEntityId ?? '',
    lightEntityId: room.lightEntityId ?? '',
    windowEntityId: room.windowEntityId ?? '',
    climateEntityId: room.climateEntityId ?? '',
    speakerEntityId: room.speakerEntityId ?? '',
    coverEntityId: room.coverEntityId ?? '',
    expanded: false,
  );

  final int id;
  String name;
  String temperatureEntityId;
  String secondaryEntityId;
  String lightEntityId;
  String windowEntityId;
  String climateEntityId;
  String speakerEntityId;
  String coverEntityId;
  bool expanded;

  /// True when the user has put something into this row besides the name —
  /// used to warn before a blank-named row silently vanishes on save,
  /// rather than after, when there'd be nothing left on screen explaining
  /// where the entities they'd typed went.
  bool get hasEntityData => configuredEntityCount > 0;

  /// How many of the 7 optional entity fields are filled in — shown as a
  /// quick summary while the row is collapsed, so there's still some
  /// visibility into a room's configuration without expanding it.
  int get configuredEntityCount => [
    temperatureEntityId,
    secondaryEntityId,
    lightEntityId,
    windowEntityId,
    climateEntityId,
    speakerEntityId,
    coverEntityId,
  ].where((v) => v.trim().isNotEmpty).length;

  RoomConfig toConfig() => RoomConfig(
    name: name.trim(),
    temperatureEntityId: temperatureEntityId,
    secondaryEntityId: secondaryEntityId,
    lightEntityId: lightEntityId,
    windowEntityId: windowEntityId,
    climateEntityId: climateEntityId,
    speakerEntityId: speakerEntityId,
    coverEntityId: coverEntityId,
  );
}

/// Settings section letting the user build the Divisões page's room list —
/// this app has no rooms baked in, so the list starts empty and grows
/// however many the user adds, each wired to its own real HA entities.
/// Unlike the energy card's 4 device slots, there's no fixed layout to cap
/// against, so any number of rooms is allowed.
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
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    final rooms = ref.read(roomsProvider);
    _draft = [for (final r in rooms) _RoomDraftEntry.from(_nextId++, r)];
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  void _addRoom() {
    setState(() {
      _draft = [..._draft, _RoomDraftEntry.blank(_nextId++)];
      _setSaved(false);
    });
  }

  void _removeRoom(int id) {
    setState(() {
      _draft = _draft.where((e) => e.id != id).toList();
      _setSaved(false);
    });
  }

  void _updateRoom(int id, void Function(_RoomDraftEntry entry) apply) {
    setState(() {
      apply(_draft.firstWhere((e) => e.id == id));
      _setSaved(false);
    });
  }

  void _reorder(int index, int newIndex) {
    setState(() {
      final entry = _draft.removeAt(index);
      _draft.insert(newIndex, entry);
      _setSaved(false);
    });
  }

  Future<void> _save() async {
    final rooms = [for (final e in _draft) if (e.name.trim().isNotEmpty) e.toConfig()];
    // A row with entities typed in but no name would otherwise vanish
    // silently right here (the filter above drops it) — surface that
    // instead of just losing it, since "I filled this in and it's gone" is
    // indistinguishable from a real save failure otherwise.
    final droppedCount = _draft.where((e) => e.name.trim().isEmpty && e.hasEntityData).length;
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
    if (droppedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            droppedCount == 1
                ? '1 divisão sem nome não foi guardada — adicione um nome e guarde outra vez.'
                : '$droppedCount divisões sem nome não foram guardadas — adicione um nome e guarde outra vez.',
          ),
          backgroundColor: NocturneColors.solarMark,
        ),
      );
    }
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
                SizedBox(width: 8),
                Text('DIVISÕES', style: NocturneText.cardKicker),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'As divisões mostradas na página Divisões, pela ordem aqui. Cada campo é opcional — uma divisão só mostra o que tiver configurado.',
              style: NocturneText.body,
            ),
            const SizedBox(height: 18),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: _reorder,
              children: [
                for (var i = 0; i < _draft.length; i++)
                  _RoomRow(
                    key: ValueKey(_draft[i].id),
                    index: i,
                    entry: _draft[i],
                    onUpdate: _updateRoom,
                    onRemove: () => _removeRoom(_draft[i].id),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _addRoom,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar divisão'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({super.key, required this.index, required this.entry, required this.onUpdate, required this.onRemove});

  /// This row's position in the list — `ReorderableListView` needs it to
  /// know which item a drag on [ReorderableDragStartListener] started from.
  final int index;
  final _RoomDraftEntry entry;
  final void Function(int id, void Function(_RoomDraftEntry entry) apply) onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final missingName = entry.name.trim().isEmpty && entry.hasEntityData;
    final title = entry.name.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The only drag-initiating widget on the row — the rest
                // stays a normal tappable header, so dragging never fights
                // the expand/collapse toggle for the same touch.
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Icon(Icons.drag_indicator, color: NocturneColors.neutral600),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Sem nome' : title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: title.isEmpty ? NocturneColors.neutral500 : NocturneColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => onUpdate(entry.id, (e) => e.expanded = !e.expanded),
                  icon: Icon(entry.expanded ? Icons.expand_less : Icons.expand_more, color: NocturneColors.neutral500),
                  tooltip: entry.expanded ? 'Colapsar' : 'Expandir',
                ),
              ],
            ),
            if (missingName) ...[
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text('Sem nome — esta divisão não vai ser guardada.', style: TextStyle(fontSize: 14, color: NocturneColors.solarMark)),
              ),
            ],
            if (!entry.expanded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  entry.configuredEntityCount == 0
                      ? 'Nenhuma entidade configurada'
                      : '${entry.configuredEntityCount} de 7 entidades configuradas',
                  style: NocturneText.caption,
                ),
              ),
            ],
            if (entry.expanded) ...[
              const SizedBox(height: 12),
              _RoomNameField(initialValue: entry.name, onChanged: (v) => onUpdate(entry.id, (e) => e.name = v)),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Temperatura',
                hint: 'sensor.quarto_temperature',
                initialValue: entry.temperatureEntityId,
                domainFilter: 'sensor',
                onChanged: (v) => onUpdate(entry.id, (e) => e.temperatureEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Sensor secundário (opcional)',
                hint: 'sensor.quarto_humidity ou lock.quarto',
                initialValue: entry.secondaryEntityId,
                onChanged: (v) => onUpdate(entry.id, (e) => e.secondaryEntityId = v),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text(
                  'Humidade, CO₂ ou fechadura mostram uma frase; qualquer outro sensor mostra o valor tal e qual. Sem isto, mostra a posição dos estores (se configurados).',
                  style: NocturneText.caption,
                ),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Luz',
                hint: 'light.quarto ou switch.quarto',
                initialValue: entry.lightEntityId,
                onChanged: (v) => onUpdate(entry.id, (e) => e.lightEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Janela',
                hint: 'binary_sensor.quarto_window',
                initialValue: entry.windowEntityId,
                domainFilter: 'binary_sensor',
                onChanged: (v) => onUpdate(entry.id, (e) => e.windowEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Ar condicionado',
                hint: 'climate.quarto ou switch.quarto_ac',
                initialValue: entry.climateEntityId,
                onChanged: (v) => onUpdate(entry.id, (e) => e.climateEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Altifalante',
                hint: 'media_player.quarto',
                initialValue: entry.speakerEntityId,
                domainFilter: 'media_player',
                onChanged: (v) => onUpdate(entry.id, (e) => e.speakerEntityId = v),
              ),
              const SizedBox(height: 12),
              EntityIdField(
                label: 'Estores',
                hint: 'cover.quarto_estores',
                initialValue: entry.coverEntityId,
                domainFilter: 'cover',
                onChanged: (v) => onUpdate(entry.id, (e) => e.coverEntityId = v),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, size: 20, color: NocturneColors.red),
                  label: Text('Remover divisão', style: TextStyle(color: NocturneColors.red)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A free-form field for the room's display name — unlike the entity
/// fields, this isn't an HA id, so it's a plain keyboard-wired text field
/// rather than `EntityIdField`'s autocomplete.
class _RoomNameField extends StatefulWidget {
  const _RoomNameField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_RoomNameField> createState() => _RoomNameFieldState();
}

class _RoomNameFieldState extends State<_RoomNameField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: const InputDecoration(
        labelText: 'Nome',
        labelStyle: TextStyle(fontSize: 16),
        hintText: 'Sala',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(),
      ),
    );
  }
}
