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
  late DateTime _endDay = _date;

  /// Which of INÍCIO/FIM the month grid edits.
  bool _editingEnd = false;

  /// Month shown, as months from the current one (0 … [_maxMonths]).
  int _monthOff = 0;
  int _navDir = 0;
  int _navTick = 0;
  bool _allDay = false;
  int _start = 9 * 60, _end = 10 * 60;
  EventRepeat _repeat = EventRepeat.none;
  bool _busy = false;

  static const _max = 23 * 60 + 45;
  static const _maxMonths = 12;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _monthOff = _offOf(_date).clamp(0, _maxMonths);
  }

  DateTime get _today => dateOnly(DateTime.now());

  int _offOf(DateTime d) => (d.year - _today.year) * 12 + d.month - _today.month;

  bool get _multi => _endDay.isAfter(_date);

  /// Sets the date of whichever end is being edited. Moving the start keeps
  /// the event's length in days; an end before the start becomes the new
  /// (single) day.
  void _pick(DateTime day) {
    final k = dateOnly(day);
    if (_editingEnd) {
      if (k.isBefore(_date)) {
        _date = k;
        _endDay = k;
      } else {
        _endDay = k;
      }
      if (!_multi && _end <= _start) _end = (_start + 60).clamp(0, _max);
    } else {
      final span = daysBetween(_date, _endDay);
      _date = k;
      _endDay = addDays(k, span);
    }
  }

  void _showMonthOf(DateTime d) {
    final off = _offOf(d).clamp(0, _maxMonths);
    if (off == _monthOff) return;
    _navDir = off > _monthOff ? 1 : -1;
    _navTick++;
    _monthOff = off;
  }

  /// "Sábado, 17 out"
  static String _short(DateTime d) => '${PtDates.cap(PtDates.weekdays[d.weekday - 1].split('-').first)}, ${PtDates.short(d)}';

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
        endDay: _endDay,
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
    final hasTitle = _title.text.trim().isNotEmpty;
    final spanDays = daysBetween(_date, _endDay);
    // In a multi-day event the end time is on the last day.
    final dur = spanDays * 1440 + _end - _start;
    final durLabel = [
      if (dur ~/ 1440 > 0) '${dur ~/ 1440} ${dur ~/ 1440 == 1 ? 'dia' : 'dias'}',
      if (dur % 1440 ~/ 60 > 0) '${dur % 1440 ~/ 60} h',
      if (dur % 60 > 0) '${dur % 60} min',
    ].join(' ');

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
              const Expanded(child: KFieldLabel('DATA')),
              for (final (label, day) in [('Hoje', _today), ('Amanhã', addDays(_today, 1))]) ...[
                const SizedBox(width: 10),
                KChip(
                  label: label,
                  on: sameDay(_editingEnd ? _endDay : _date, day),
                  height: 52,
                  fontSize: 20,
                  padX: 22,
                  onTap: () => setState(() {
                    _pick(day);
                    _showMonthOf(day);
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final end in [false, true]) ...[
                if (end) const SizedBox(width: 14),
                Expanded(
                  child: KPress(
                    onTap: () => setState(() {
                      _editingEnd = end;
                      _showMonthOf(end ? _endDay : _date);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: _editingEnd == end ? Colors.white : KColors.sub,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _editingEnd == end ? KColors.accent : Colors.transparent, width: 3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            end ? (_multi ? 'FIM · ${spanDays + 1} DIAS' : 'FIM') : 'INÍCIO',
                            style: KText.s(15, weight: FontWeight.w700, spacing: 1, color: _editingEnd == end ? KColors.accent : KColors.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(end && !_multi ? 'Mesmo dia' : _short(end ? _endDay : _date), style: KText.s(22, weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _MonthPicker(
            month: DateTime(_today.year, _today.month + _monthOff),
            start: _date,
            end: _endDay,
            today: _today,
            navDir: _navDir,
            navTick: _navTick,
            canPrev: _monthOff > 0,
            canNext: _monthOff < _maxMonths,
            onMonth: (delta) => setState(() {
              _navDir = delta;
              _navTick++;
              _monthOff = (_monthOff + delta).clamp(0, _maxMonths);
            }),
            onPick: (d) {
              final off = _offOf(d);
              if (off < 0 || off > _maxMonths) return;
              setState(() {
                _pick(d);
                _showMonthOf(d);
              });
            },
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
                timeBox(_multi ? 'Início · ${_short(_date)}' : 'Início', _start, () => _moveStart(-15), () => _moveStart(15)),
                const SizedBox(width: 16),
                timeBox(
                  _multi ? 'Fim · ${_short(_endDay)}' : 'Fim',
                  _end,
                  () => setState(() => _end = (_end - 15).clamp(_multi ? 0 : _start + 15, _max)),
                  () => setState(() => _end = (_end + 15).clamp(_multi ? 0 : _start + 15, _max)),
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
    // Across several days the end time is on another day: start moves alone.
    if (_multi) {
      _start = (_start + delta).clamp(0, _max);
      return;
    }
    final dur = _end - _start;
    _start = (_start + delta).clamp(0, _max - 15);
    _end = (_start + dur).clamp(_start + 15, _max);
  });
}

/// The month grid of "Novo evento": six weeks, Monday first; today ringed,
/// past days dimmed, holidays red with a dot, the event's days filled.
class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({
    required this.month,
    required this.start,
    required this.end,
    required this.today,
    required this.navDir,
    required this.navTick,
    required this.canPrev,
    required this.canNext,
    required this.onMonth,
    required this.onPick,
  });

  final DateTime month;
  final DateTime start;
  final DateTime end;
  final DateTime today;
  final int navDir;
  final int navTick;
  final bool canPrev;
  final bool canNext;
  final ValueChanged<int> onMonth;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridStart = addDays(month, -(month.weekday - 1));
    final events = ref.watch(calendarRangeProvider((start: gridStart, end: addDays(gridStart, 42)))).valueOrNull ?? const <KEvent>[];
    final holidays = events.where((e) => e.source.holiday && e.allDay).toList();
    final rangeBg = Color.lerp(Colors.white, KColors.accent, 0.16)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Row(
            children: [
              KCircleButton(
                icon: KIcons.chevronLeft,
                size: 52,
                border: null,
                fg: canPrev ? KColors.ink : KColors.ring,
                onTap: canPrev ? () => onMonth(-1) : null,
              ),
              Expanded(
                child: Text(PtDates.monthYear(month), textAlign: TextAlign.center, style: KText.d(26)),
              ),
              KCircleButton(
                icon: KIcons.chevronRight,
                size: 52,
                border: null,
                fg: canNext ? KColors.ink : KColors.ring,
                onTap: canNext ? () => onMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PtDates.letters[i],
                    textAlign: TextAlign.center,
                    style: KText.s(15, weight: FontWeight.w700, spacing: 1, color: i > 4 ? KColors.ink : KColors.muted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            key: ValueKey(navTick),
            tween: Tween(begin: navDir == 0 ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: kEase,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(48 * navDir * (1 - t), 0), child: child),
            ),
            child: Column(
              children: [
                for (var row = 0; row < 6; row++) ...[
                  if (row > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++) ...[
                        if (col > 0) const SizedBox(width: 8),
                        Expanded(child: _dayCell(addDays(gridStart, row * 7 + col), holidays, rangeBg)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime d, List<KEvent> holidays, Color rangeBg) {
    final inMonth = d.month == month.month;
    final on = sameDay(d, start) || sameDay(d, end);
    final inRange = d.isAfter(start) && d.isBefore(end);
    final isToday = sameDay(d, today);
    final past = d.isBefore(today);
    final holiday = holidays.any((h) => h.coversDay(d));
    final weekend = d.weekday >= 6;
    final fg = on
        ? Colors.white
        : !inMonth
        ? KColors.ring
        : holiday
        ? KColors.red
        : past
        ? const Color(0xFFA39E94)
        : KColors.ink;
    return KPress(
      onTap: () => onPick(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 60,
        decoration: BoxDecoration(
          color: on ? KColors.accent : (inRange ? rangeBg : (inMonth && !past ? Colors.white : Colors.transparent)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isToday && !on ? KColors.accent : Colors.transparent, width: 2.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${d.day}',
              style: KText.d(24, color: fg, weight: on || isToday ? FontWeight.w600 : (weekend && inMonth ? FontWeight.w500 : FontWeight.w400)),
            ),
            if (holiday && inMonth)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: on ? Colors.white : KColors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
