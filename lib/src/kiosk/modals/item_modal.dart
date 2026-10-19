import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/todo_data.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

/// Suggestions offered for a new item, per kind of list.
const _suggestions = {
  'cart': ['Azeite', 'Arroz', 'Manteiga', 'Fruta', 'Água', 'Papel higiénico', 'Queijo', 'Leite', 'Pão', 'Ovos'],
  'pill': ['Ibuprofeno', 'Paracetamol', 'Soro fisiológico', 'Termómetro', 'Pensos rápidos'],
  'home': ['Pilhas', 'Lâmpadas', 'Silicone', 'Parafusos'],
};

Future<void> showItemModal(BuildContext context, {required TodoListInfo list, TodoItem? item, List<TodoItem> existing = const []}) =>
    showKModal(context, (_) => ItemModal(list: list, item: item, existing: existing));

/// Add or edit one list item (the design's "Modal de artigo"): name,
/// quantity with unit, and a note. The same modal serves Listas and the
/// Início "Compras" card.
class ItemModal extends ConsumerStatefulWidget {
  const ItemModal({super.key, required this.list, this.item, this.existing = const []});

  final TodoListInfo list;
  final TodoItem? item;
  final List<TodoItem> existing;

  @override
  ConsumerState<ItemModal> createState() => _ItemModalState();
}

class _ItemModalState extends ConsumerState<ItemModal> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _note = TextEditingController(text: widget.item?.note ?? '');
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();
  late double _qty = widget.item?.qty ?? 0;
  late String _unit = widget.item?.unit ?? 'un';
  bool _busy = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  List<String> _suggest(String text) {
    if (!_isNew) return const [];
    final q = text.trim().toLowerCase();
    final pending = widget.existing.where((i) => !i.done).map((i) => i.name.toLowerCase()).toSet();
    return (_suggestions[widget.list.icon] ?? const [])
        .where((s) => !pending.contains(s.toLowerCase()) && (q.isEmpty || s.toLowerCase().startsWith(q)))
        .toList();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final actions = ref.read(todoActionsProvider);
    try {
      if (_isNew) {
        await actions.add(widget.list.entityId, name: name, qty: _qty, unit: _unit, note: _note.text);
      } else {
        await actions.update(widget.list.entityId, widget.item!, name: name, qty: _qty, unit: _unit, note: _note.text.trim());
      }
      OnScreenKeyboardController.instance.close();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      KToast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    try {
      await ref.read(todoActionsProvider).remove(widget.list.entityId, widget.item!);
      OnScreenKeyboardController.instance.close();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qtyText = todoQtyText(_qty, _unit);
    final step = todoUnitStep(_unit);
    return KModal(
      keyboardTop: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KModalHeader(title: _isNew ? 'Novo artigo' : 'Editar artigo'),
          const SizedBox(height: 24),
          const KFieldLabel('ARTIGO'),
          const SizedBox(height: 12),
          KTextField(
            controller: _name,
            focusNode: _nameFocus,
            autofocus: _isNew,
            options: KeyboardOptions(
              suggestions: _suggest,
              doneLabel: 'Seguinte',
              onDone: () => _noteFocus.requestFocus(),
              onSuggest: (s) {
                _name.text = s;
                _noteFocus.requestFocus();
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const KFieldLabel('QUANTIDADE'),
              const Spacer(),
              Text(qtyText.isEmpty ? 'Sem quantidade' : qtyText, style: KText.s(22, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(26)),
                child: Row(
                  children: [
                    KStepButton(plus: false, onTap: () => setState(() => _qty = (_qty - step).clamp(0, 9999))),
                    SizedBox(
                      width: 108,
                      child: Text(_qty > 0 ? todoQtyText(_qty, _unit).split(' ').first : '–', textAlign: TextAlign.center, style: KText.d(40)),
                    ),
                    KStepButton(plus: true, onTap: () => setState(() => _qty = (_qty + step).clamp(0, 9999))),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in todoUnits.entries)
                      KChip(
                        label: e.value.$2,
                        on: _unit == e.key,
                        padX: 24,
                        onTap: () => setState(() {
                          _unit = e.key;
                          if (_qty == 0) _qty = e.key == 'g' ? 100 : 1;
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const KFieldLabel('NOTA', optional: true),
          const SizedBox(height: 12),
          KTextField(controller: _note, focusNode: _noteFocus, hint: 'Ex.: em grão, marca, sem lactose…', height: 80, fontSize: 24),
          const SizedBox(height: 24),
          KModalFooter(
            saveLabel: _isNew ? 'Adicionar' : 'Guardar',
            canSave: _name.text.trim().isNotEmpty,
            busy: _busy,
            onSave: _save,
            onDelete: _isNew ? null : _delete,
          ),
        ],
      ),
    );
  }
}
