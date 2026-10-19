import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/chores_data.dart';
import '../data/family_data.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

const _suggestions = [
  'Arrumar o quarto',
  'Fazer a cama',
  'Limpar o pó',
  'Estender a roupa',
  'Lavar o carro',
  'Esvaziar a máquina da loiça',
  'Levar o lixo',
  'Regar as plantas',
];

Future<void> showTaskModal(BuildContext context, {Chore? chore, required DateTime day}) => showKModal(context, (_) => TaskModal(chore: chore, day: day));

enum _Repeat { none, daily, days }

/// Create or edit a household task (the design's "Modal de tarefa"): what,
/// for whom, which days, and an optional deadline.
class TaskModal extends ConsumerStatefulWidget {
  const TaskModal({super.key, this.chore, required this.day});

  final Chore? chore;

  /// The day a one-off task lands on (the day selected on Tarefas, or today).
  final DateTime day;

  @override
  ConsumerState<TaskModal> createState() => _TaskModalState();
}

class _TaskModalState extends ConsumerState<TaskModal> {
  late final _name = TextEditingController(text: widget.chore?.title ?? '');
  late String? _who = widget.chore?.who;
  late _Repeat _repeat = widget.chore == null
      ? _Repeat.none
      : widget.chore!.days == null
      ? _Repeat.none
      : (widget.chore!.days!.length == 7 ? _Repeat.daily : _Repeat.days);
  late List<int> _days = widget.chore?.days ?? [widget.day.weekday - 1];
  late bool _hasDue = (widget.chore?.due ?? '').isNotEmpty;
  late int _due = _hasDue ? PtDates.toMinutes(widget.chore!.due) : 20 * 60;

  bool get _isNew => widget.chore == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<FamilyMember> members) async {
    final title = _name.text.trim();
    if (title.isEmpty) return;
    final who = _who ?? members.last.id;
    final chore = Chore(
      id: widget.chore?.id ?? 't${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      who: who,
      days: switch (_repeat) {
        _Repeat.none => null,
        _Repeat.daily => const [0, 1, 2, 3, 4, 5, 6],
        _Repeat.days => (_days..sort()),
      },
      date: _repeat == _Repeat.none ? (widget.chore?.date ?? PtDates.key(widget.day)) : null,
      due: _hasDue ? PtDates.minutes(_due) : '',
    );
    OnScreenKeyboardController.instance.close();
    Navigator.of(context).pop();
    try {
      await ref.read(choresProvider.notifier).upsert(chore);
    } catch (e) {
      KToast.error(e);
    }
  }

  Future<void> _delete() async {
    OnScreenKeyboardController.instance.close();
    Navigator.of(context).pop();
    try {
      await ref.read(choresProvider.notifier).remove(widget.chore!.id);
    } catch (e) {
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyMembersProvider);
    final who = _who ?? (members.isEmpty ? null : members.last.id);
    return KModal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KModalHeader(title: _isNew ? 'Nova tarefa' : 'Editar tarefa'),
          const SizedBox(height: 24),
          const KFieldLabel('TAREFA'),
          const SizedBox(height: 12),
          KTextField(
            controller: _name,
            hint: 'Ex.: Arrumar o quarto',
            autofocus: _isNew,
            options: KeyboardOptions(
              suggestions: (t) {
                final q = t.trim().toLowerCase();
                return _suggestions.where((s) => q.isEmpty || s.toLowerCase().startsWith(q)).toList();
              },
              onSuggest: (s) {
                _name.text = s;
                OnScreenKeyboardController.instance.close();
              },
            ),
          ),
          const SizedBox(height: 24),
          const KFieldLabel('PARA QUEM'),
          const SizedBox(height: 12),
          KPersonPicker(members: members, selected: who, onPick: (id) => setState(() => _who = id)),
          const SizedBox(height: 24),
          const KFieldLabel('REPETIR'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              KChip(label: 'Não repete', on: _repeat == _Repeat.none, padX: 26, onTap: () => setState(() => _repeat = _Repeat.none)),
              KChip(label: 'Todos os dias', on: _repeat == _Repeat.daily, padX: 26, onTap: () => setState(() => _repeat = _Repeat.daily)),
              KChip(label: 'Dias específicos', on: _repeat == _Repeat.days, padX: 26, onTap: () => setState(() => _repeat = _Repeat.days)),
            ],
          ),
          if (_repeat == _Repeat.days) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: KPress(
                      onTap: () => setState(() {
                        final next = [..._days];
                        if (!next.remove(i)) next.add(i);
                        if (next.isNotEmpty) _days = next;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _days.contains(i) ? KColors.accent : KColors.chip, borderRadius: BorderRadius.circular(22)),
                        child: Text(
                          PtDates.letters[i],
                          style: KText.s(24, weight: FontWeight.w700, color: _days.contains(i) ? Colors.white : KColors.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: KFieldLabel('HORA LIMITE')),
              KPress(
                onTap: () => setState(() => _hasDue = !_hasDue),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
                  decoration: BoxDecoration(color: KColors.chip, borderRadius: BorderRadius.circular(32)),
                  child: Row(
                    children: [
                      Text('Até uma hora', style: KText.s(22, weight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      KSwitch(on: _hasDue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_hasDue) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 8, 10, 8),
              decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(26)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Até às ', style: KText.s(22, color: KColors.muted)),
                  Text(PtDates.minutes(_due), style: KText.d(40)),
                  const Spacer(),
                  KStepButton(plus: false, onTap: () => setState(() => _due = (_due - 15).clamp(0, 23 * 60 + 45))),
                  const SizedBox(width: 10),
                  KStepButton(plus: true, onTap: () => setState(() => _due = (_due + 15).clamp(0, 23 * 60 + 45))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          KModalFooter(
            saveLabel: _isNew ? 'Criar tarefa' : 'Guardar',
            canSave: _name.text.trim().isNotEmpty && members.isNotEmpty,
            onSave: () => _save(members),
            onDelete: _isNew ? null : _delete,
          ),
        ],
      ),
    );
  }
}

/// The "Para quem" row: one large tile per family member, ringed in their
/// colour when chosen.
class KPersonPicker extends StatelessWidget {
  const KPersonPicker({super.key, required this.members, required this.selected, required this.onPick, this.showCheck = false});

  final List<FamilyMember> members;
  final String? selected;
  final ValueChanged<String> onPick;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final cols = members.length.clamp(1, 3);
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 14 * (cols - 1)) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final m in members)
              SizedBox(
                width: w,
                child: KPress(
                  onTap: () => onPick(m.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: selected == m.id ? m.color.tint : KColors.sub,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: selected == m.id ? m.color.color : Colors.transparent, width: 3),
                    ),
                    child: Row(
                      children: [
                        KAvatar(initial: m.initial, color: m.color.color, size: 44, fontSize: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KText.s(22, weight: FontWeight.w600),
                          ),
                        ),
                        if (showCheck && selected == m.id) KIcon(KIcons.check, size: 30, color: m.color.color, stroke: 2.6),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
