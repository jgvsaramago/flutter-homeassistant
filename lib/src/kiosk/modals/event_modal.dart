import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/on_screen_keyboard_controller.dart';
import '../data/calendar_data.dart';
import '../data/family_data.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';
import 'task_modal.dart';

/// Opens "Novo evento" for [day]; returns the day the event was created
/// on, or null if cancelled.
Future<DateTime?> showEventModal(BuildContext context, {required DateTime day}) => showKModal<DateTime>(context, (_) => EventModal(day: day));

const _titleSuggestions = ['Jantar', 'Almoço', 'Consulta', 'Aniversário', 'Escola', 'Ginásio', 'Reunião'];

/// The design's "Modal novo evento": title, whose calendar, a two-week
/// date strip, all-day or start/end times in 15-minute steps, place,
/// repetition and notes.
class EventModal extends ConsumerStatefulWidget {
  const EventModal({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<EventModal> createState() => _EventModalState();
}

class _EventModalState extends ConsumerState<EventModal> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _titleFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _notesFocus = FocusNode();
  String? _source;
  late DateTime _date = dateOnly(widget.day);
  int _page = 0;
  bool _allDay = false;
  int _start = 9 * 60, _end = 10 * 60;
  EventRepeat _repeat = EventRepeat.none;
  bool _busy = false;

  static const _max = 23 * 60 + 45;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    final today = dateOnly(DateTime.now());
    final offset = daysBetween(today, _date);
    if (offset >= 0) _page = (offset ~/ 14).clamp(0, 3);
  }

  @override
  void dispose() {
    for (final c in [_title, _location, _notes]) {
      c.dispose();
    }
    for (final f in [_titleFocus, _locationFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save(CalendarSource source) async {
    setState(() => _busy = true);
    try {
      await createKioskEvent(
        ref,
        source: source,
        title: _title.text.trim(),
        day: _date,
        allDay: _allDay,
        startMinutes: _start,
        endMinutes: _end,
        repeat: _repeat,
        location: _location.text.trim(),
        notes: _notes.text.trim(),
      );
      OnScreenKeyboardController.instance.close();
      final d = _date;
      KToast.show(
        'Evento criado: ${_title.text.trim()} · ${PtDates.abbrLower[d.weekday - 1]} ${d.day} ${PtDates.months[d.month - 1].substring(0, 3)}${_allDay ? ', dia todo' : ', ${PtDates.minutes(_start)}'}',
      );
      if (mounted) Navigator.of(context).pop(d);
    } catch (e) {
      KToast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(calendarSourcesProvider).where((s) => s.writable).toList();
    final selected =
        sources.where((s) => s.entityId == _source).firstOrNull ??
        sources.where((s) => s.name.toLowerCase().contains('fam')).firstOrNull ??
        sources.firstOrNull;
    final today = dateOnly(DateTime.now());
    final hasTitle = _title.text.trim().isNotEmpty;
    final dur = _end - _start;
    final durLabel = [if (dur ~/ 60 > 0) '${dur ~/ 60} h', if (dur % 60 > 0) '${dur % 60} min'].join(' ');

    Widget timeBox(String label, int value, VoidCallback dec, VoidCallback inc) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
        decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: KText.s(18, weight: FontWeight.w600, color: KColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(PtDates.minutes(value), style: KText.d(44, spacing: -1, height: 1)),
                ],
              ),
            ),
            KStepButton(plus: false, onTap: dec),
            const SizedBox(width: 10),
            KStepButton(plus: true, onTap: inc),
          ],
        ),
      ),
    );

    return KModal(
      keyboardTop: 64,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KModalHeader(title: 'Novo evento'),
          const SizedBox(height: 28),
          const KFieldLabel('TÍTULO'),
          const SizedBox(height: 12),
          KTextField(
            controller: _title,
            focusNode: _titleFocus,
            hint: 'Ex.: Jantar com amigos',
            autofocus: true,
            options: KeyboardOptions(
              suggestions: (t) => t.trim().isEmpty ? _titleSuggestions : const [],
              doneLabel: 'Seguinte',
              onDone: () => _locationFocus.requestFocus(),
              onSuggest: (s) => _title.value = TextEditingValue(
                text: '$s ',
                selection: TextSelection.collapsed(offset: s.length + 1),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const KFieldLabel('PARA QUEM'),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            Text('Nenhum calendário com escrita configurado.', style: KText.s(20, color: KColors.muted))
          else
            KPersonPicker(
              members: [for (final s in sources) FamilyMember(id: s.entityId, name: s.name, color: s.color)],
              selected: selected?.entityId,
              showCheck: true,
              onPick: (id) => setState(() => _source = id),
            ),
          const SizedBox(height: 28),
          Row(
            children: [
              const KFieldLabel('DATA'),
              const SizedBox(width: 16),
              Expanded(
                child: Text(PtDates.long(_date), style: KText.s(24, weight: FontWeight.w600)),
              ),
              KCircleButton(
                icon: KIcons.chevronLeft,
                size: 60,
                fg: _page > 0 ? KColors.ink : KColors.disabledFg,
                onTap: _page > 0 ? () => setState(() => _page--) : null,
              ),
              const SizedBox(width: 10),
              KCircleButton(icon: KIcons.chevronRight, size: 60, onTap: _page < 3 ? () => setState(() => _page++) : null),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 98 / 96,
            children: [
              for (var i = 0; i < 14; i++)
                () {
                  final d = addDays(today, _page * 14 + i);
                  final on = sameDay(d, _date);
                  final rel = _page * 14 + i;
                  final sub = on ? Colors.white : KColors.muted;
                  return KPress(
                    onTap: () => setState(() => _date = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(color: on ? KColors.accent : KColors.sub, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            PtDates.abbr[d.weekday - 1],
                            style: KText.s(16, weight: FontWeight.w700, color: sub, spacing: 1),
                          ),
                          Text('${d.day}', style: KText.d(30, color: on ? Colors.white : KColors.ink, height: 1.15)),
                          Text(
                            rel == 0 ? 'Hoje' : (rel == 1 ? 'Amanhã' : PtDates.months[d.month - 1].substring(0, 3)),
                            style: KText.s(15, weight: FontWeight.w600, color: sub),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: KFieldLabel('HORÁRIO')),
              KPress(
                onTap: () => setState(() => _allDay = !_allDay),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
                  decoration: BoxDecoration(color: KColors.chip, borderRadius: BorderRadius.circular(32)),
                  child: Row(
                    children: [
                      Text('Dia inteiro', style: KText.s(22, weight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      KSwitch(on: _allDay),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!_allDay) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                timeBox('Início', _start, () => _moveStart(-15), () => _moveStart(15)),
                const SizedBox(width: 16),
                timeBox(
                  'Fim',
                  _end,
                  () => setState(() => _end = (_end - 15).clamp(_start + 15, _max)),
                  () => setState(() => _end = (_end + 15).clamp(_start + 15, _max)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Duração: $durLabel', style: KText.s(20, color: KColors.muted)),
          ],
          const SizedBox(height: 28),
          const KFieldLabel('LOCAL', optional: true),
          const SizedBox(height: 12),
          KTextField(
            controller: _location,
            focusNode: _locationFocus,
            hint: 'Ex.: Casa da avó',
            height: 80,
            leading: const KIcon(KIcons.pin, size: 28, color: KColors.muted),
            options: KeyboardOptions(doneLabel: 'Seguinte', onDone: () => _notesFocus.requestFocus()),
          ),
          const SizedBox(height: 28),
          const KFieldLabel('REPETIR'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (r, label) in const [
                (EventRepeat.none, 'Não repete'),
                (EventRepeat.daily, 'Todos os dias'),
                (EventRepeat.weekly, 'Todas as semanas'),
                (EventRepeat.monthly, 'Todos os meses'),
              ])
                KChip(label: label, on: _repeat == r, onTap: () => setState(() => _repeat = r)),
            ],
          ),
          const SizedBox(height: 28),
          const KFieldLabel('NOTAS', optional: true),
          const SizedBox(height: 12),
          KTextField(controller: _notes, focusNode: _notesFocus, hint: 'Detalhes, o que levar, contactos…', height: 120, fontSize: 22, maxLines: 3),
          const SizedBox(height: 28),
          KModalFooter(
            saveLabel: 'Guardar evento',
            canSave: hasTitle && selected != null,
            busy: _busy,
            hint: hasTitle
                ? (selected == null ? 'Sem calendário onde guardar' : 'Será adicionado ao calendário de ${selected.name}')
                : 'Escreva um título para guardar',
            onSave: () => _save(selected!),
          ),
        ],
      ),
    );
  }

  void _moveStart(int delta) => setState(() {
    final dur = _end - _start;
    _start = (_start + delta).clamp(0, _max - 15);
    _end = (_start + dur).clamp(_start + 15, _max);
  });
}
