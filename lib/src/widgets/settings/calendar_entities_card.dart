import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_entities_provider.dart';
import '../../providers/calendar_entities_store.dart';
import '../../theme/nocturne_theme.dart';
import '../entity_id_field.dart';
import 'settings_save_controller.dart';

/// One row being edited — a synthetic [id] (not the entity id, which is
/// mutable and briefly empty/duplicated while typing) gives each row a
/// stable [Key] across add/remove, so `EntityIdField`'s own internal
/// `TextEditingController` stays attached to the right row instead of
/// scrambling when the list above or below it changes length.
class _DraftEntry {
  _DraftEntry({required this.id, required this.entityId, required this.color});
  final int id;
  String entityId;
  CalendarColorKey color;
}

/// Settings section letting the user build the calendar sheet's calendar
/// list from real HA `calendar.*` entities — this app has no household
/// calendar wired in by default, so the list starts empty and grows however
/// many the user adds, each with its own colour.
class CalendarEntitiesCard extends ConsumerStatefulWidget {
  const CalendarEntitiesCard({super.key, this.saveController});

  /// When set, this card's save button floats at the page level instead of
  /// rendering inline — see `SettingsSaveController`.
  final SettingsSaveController? saveController;

  @override
  ConsumerState<CalendarEntitiesCard> createState() => _CalendarEntitiesCardState();
}

class _CalendarEntitiesCardState extends ConsumerState<CalendarEntitiesCard> {
  late List<_DraftEntry> _draft;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _draft = [for (final entry in ref.read(calendarEntriesProvider)) _DraftEntry(id: _nextId++, entityId: entry.entityId, color: entry.color)];
    widget.saveController?.bind(_save);
  }

  void _setSaved(bool value) => widget.saveController?.saved.value = value;

  void _addEntry() {
    setState(() {
      _draft = [..._draft, _DraftEntry(id: _nextId++, entityId: '', color: CalendarColorKey.values[_draft.length % CalendarColorKey.values.length])];
      _setSaved(false);
    });
  }

  void _removeEntry(int id) {
    setState(() {
      _draft = _draft.where((e) => e.id != id).toList();
      _setSaved(false);
    });
  }

  void _updateEntityId(int id, String value) {
    setState(() {
      _draft.firstWhere((e) => e.id == id).entityId = value;
      _setSaved(false);
    });
  }

  void _updateColor(int id, CalendarColorKey color) {
    setState(() {
      _draft.firstWhere((e) => e.id == id).color = color;
      _setSaved(false);
    });
  }

  Future<void> _save() async {
    final entries = [for (final e in _draft) if (e.entityId.trim().isNotEmpty) CalendarEntryConfig(entityId: e.entityId.trim(), color: e.color)];
    // A row with no entity id typed in gets silently dropped by the filter
    // above — surface that instead of just losing it, since an empty row
    // added then left blank is easy to mistake for "saving isn't working".
    final droppedCount = _draft.where((e) => e.entityId.trim().isEmpty).length;
    try {
      await ref.read(calendarEntitiesStoreProvider).save(entries);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao guardar: $error'), backgroundColor: NocturneColors.red));
      return;
    }
    ref.read(calendarEntriesProvider.notifier).state = entries;
    if (!mounted) return;
    _setSaved(true);
    if (droppedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            droppedCount == 1
                ? '1 calendário sem entidade não foi guardado — escolha uma entidade e guarde outra vez.'
                : '$droppedCount calendários sem entidade não foram guardados — escolha uma entidade e guarde outra vez.',
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
                const Icon(Icons.event_outlined, size: 20, color: NocturneColors.accent),
                const SizedBox(width: 8),
                Text('CALENDÁRIOS', style: NocturneText.cardKicker),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Escolha as entidades calendar.* a mostrar e a cor de cada uma.', style: NocturneText.body),
            const SizedBox(height: 18),
            for (final entry in _draft) ...[
              _CalendarEntryRow(
                key: ValueKey(entry.id),
                entry: entry,
                onEntityChanged: (v) => _updateEntityId(entry.id, v),
                onColorChanged: (c) => _updateColor(entry.id, c),
                onRemove: () => _removeEntry(entry.id),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar calendário'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEntryRow extends StatelessWidget {
  const _CalendarEntryRow({super.key, required this.entry, required this.onEntityChanged, required this.onColorChanged, required this.onRemove});

  final _DraftEntry entry;
  final ValueChanged<String> onEntityChanged;
  final ValueChanged<CalendarColorKey> onColorChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EntityIdField(
                  label: 'Calendário',
                  hint: 'calendar.pessoal',
                  initialValue: entry.entityId,
                  domainFilter: 'calendar',
                  onChanged: onEntityChanged,
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: NocturneColors.neutral500), tooltip: 'Remover'),
            ],
          ),
          const SizedBox(height: 12),
          _ColorSwatchPicker(selected: entry.color, onSelect: onColorChanged),
        ],
      ),
    );
  }
}

class _ColorSwatchPicker extends StatelessWidget {
  const _ColorSwatchPicker({required this.selected, required this.onSelect});

  final CalendarColorKey selected;
  final ValueChanged<CalendarColorKey> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final key in CalendarColorKey.values) ...[
          _Swatch(colorKey: key, active: key == selected, onTap: () => onSelect(key)),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colorKey, required this.active, required this.onTap});

  final CalendarColorKey colorKey;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: colorKey.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorKey.color,
            border: active ? Border.all(color: NocturneColors.text, width: 2.5) : null,
          ),
          child: active ? const Icon(Icons.check, size: 16, color: NocturneColors.bg) : null,
        ),
      ),
    );
  }
}
