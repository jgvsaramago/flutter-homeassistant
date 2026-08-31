import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/calendar_entities_provider.dart';
import '../../providers/calendar_entities_store.dart';
import '../../providers/calendar_events_provider.dart';
import '../../providers/ha_providers.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/dashboard/calendar_grid.dart';
import '../sheet.dart';
import '../sheet_parts.dart';

/// Opens the Calendar sheet: month navigation, per-calendar filter chips, a
/// fixed 42-cell day grid with event dots, and the selected day's event
/// list — all reading from the calendars configured in Definições →
/// Homepage → Calendário (see `CalendarEntitiesCard`).
Future<void> showCalendarSheet(BuildContext context) {
  return showSheet<void>(context, heightPct: 0.82, children: const [_CalendarSheetBody()]);
}

class _CalendarSheetBody extends ConsumerStatefulWidget {
  const _CalendarSheetBody();

  @override
  ConsumerState<_CalendarSheetBody> createState() => _CalendarSheetBodyState();
}

class _CalendarSheetBodyState extends ConsumerState<_CalendarSheetBody> {
  late final DateTime _today = dateOnly(DateTime.now());
  late DateTime _selectedDate = _today;
  int _monthOffset = 0;
  final Set<String> _hiddenCals = {};

  DateTime get _monthAnchor => monthAnchorForOffset(_today, _monthOffset);

  void _goToday() {
    setState(() {
      _monthOffset = 0;
      _selectedDate = _today;
    });
  }

  // Month navigation carries the selected day across (clamped to the target
  // month's length); returning to the current month re-selects today rather
  // than wherever navigation last left the clamp.
  void _shiftMonth(int delta) {
    setState(() {
      _monthOffset += delta;
      if (_monthOffset == 0) {
        _selectedDate = _today;
        return;
      }
      final anchor = monthAnchorForOffset(_today, _monthOffset);
      final day = _selectedDate.day.clamp(1, daysInMonth(anchor));
      _selectedDate = DateTime(anchor.year, anchor.month, day);
    });
  }

  void _selectDay(DateTime day) => setState(() => _selectedDate = day);

  void _toggleCal(String entityId) {
    setState(() {
      if (!_hiddenCals.add(entityId)) _hiddenCals.remove(entityId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(calendarEntriesProvider);
    final entities = ref.watch(entitiesProvider).value ?? const {};
    // `.valueOrNull`, not `.value` — see the same note in `CalendarCard`.
    final allInstances = ref.watch(calendarMonthEventsProvider(_monthAnchor)).valueOrNull ?? const [];
    final visibleInstances = [for (final i in allInstances) if (!_hiddenCals.contains(i.entityId)) i];
    final byDate = groupByDate(visibleInstances);

    final selectedEvents = (byDate[_selectedDate] ?? const []).toList()..sort((a, b) => a.event.start.compareTo(b.event.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(paddingBottom: 22),
        _HeaderRow(year: _monthAnchor.year, monthName: monthNamesPt[_monthAnchor.month - 1], onToday: _goToday, onPrev: () => _shiftMonth(-1), onNext: () => _shiftMonth(1)),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 22),
          _CalendarChips(entries: entries, entities: entities, hidden: _hiddenCals, onToggle: _toggleCal),
        ],
        const SizedBox(height: 22),
        const _WeekdayHeader(),
        const SizedBox(height: 4),
        _DayGrid(
          days: buildMonthGrid(_monthAnchor),
          monthAnchor: _monthAnchor,
          today: _today,
          selected: _selectedDate,
          eventsByDate: byDate,
          onSelect: _selectDay,
        ),
        const SizedBox(height: 22),
        _SelectedDayLine(date: _selectedDate, eventCount: selectedEvents.length),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const _EmptyNotice('Nenhum calendário configurado. Adicione um em Definições → Calendário.')
        else if (selectedEvents.isEmpty)
          const _EmptyNotice('Sem eventos neste dia')
        else
          for (var i = 0; i < selectedEvents.length; i++) ...[
            _EventRow(instance: selectedEvents[i], calendarName: _calendarName(entities, selectedEvents[i].entityId)),
            if (i != selectedEvents.length - 1) const SizedBox(height: NocturneSpacing.space5),
          ],
      ],
    );
  }

  String _calendarName(Map<String, HaEntity> entities, String entityId) => entities[entityId]?.friendlyName ?? entityId;
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.year, required this.monthName, required this.onToday, required this.onPrev, required this.onNext});

  final int year;
  final String monthName;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$year',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: NocturneColors.accent, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 2),
              Text(_capitalize(monthName), style: NocturneText.heroMetric()),
            ],
          ),
        ),
        _TodayPill(onTap: onToday),
        const SizedBox(width: NocturneSpacing.space5),
        _ChevronButton(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 10),
        _ChevronButton(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(NocturneRadii.pill), border: Border.all(color: NocturneColors.accent)),
        child: Text('Hoje', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: NocturneColors.accent, decoration: TextDecoration.none)),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: NocturneColors.neutral700)),
        child: Icon(icon, size: 26, color: NocturneColors.text),
      ),
    );
  }
}

class _CalendarChips extends StatelessWidget {
  const _CalendarChips({required this.entries, required this.entities, required this.hidden, required this.onToggle});

  final List<CalendarEntryConfig> entries;
  final Map<String, HaEntity> entities;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NocturneSpacing.space4,
      runSpacing: NocturneSpacing.space3,
      children: [
        for (final entry in entries)
          _CalendarChip(
            label: entities[entry.entityId]?.friendlyName ?? entry.entityId,
            color: entry.color.color,
            active: !hidden.contains(entry.entityId),
            onTap: () => onToggle(entry.entityId),
          ),
      ],
    );
  }
}

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({required this.label, required this.color, required this.active, required this.onTap});

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: NocturneDurations.colorChange,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? NocturneColors.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(NocturneRadii.pill),
          border: Border.all(color: active ? NocturneColors.accent.withValues(alpha: 0.55) : NocturneColors.neutral700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, color: active ? NocturneColors.text : NocturneColors.neutral400, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < weekdayInitialsPt.length; i++)
          Expanded(
            child: Text(
              weekdayInitialsPt[i],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: i == 0 || i == 6 ? NocturneColors.neutral600 : NocturneColors.neutral500, decoration: TextDecoration.none),
            ),
          ),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days, required this.monthAnchor, required this.today, required this.selected, required this.eventsByDate, required this.onSelect});

  final List<DateTime> days;
  final DateTime monthAnchor;
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, List<CalendarEventInstance>> eventsByDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          SizedBox(
            height: 78,
            child: Row(
              children: [for (var col = 0; col < 7; col++) Expanded(child: _cell(days[row * 7 + col]))],
            ),
          ),
      ],
    );
  }

  Widget _cell(DateTime date) {
    return _DayGridCell(
      date: date,
      isToday: date == today,
      isSelected: date == selected,
      isCurrentMonth: date.month == monthAnchor.month,
      isWeekend: date.weekday == DateTime.sunday || date.weekday == DateTime.saturday,
      dotColors: [for (final i in eventsByDate[date] ?? const []) i.color],
      onTap: () => onSelect(date),
    );
  }
}

class _DayGridCell extends StatelessWidget {
  const _DayGridCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isCurrentMonth,
    required this.isWeekend,
    required this.dotColors,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isCurrentMonth;
  final bool isWeekend;
  final List<Color> dotColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (isToday) {
      textColor = NocturneColors.bg;
    } else if (!isCurrentMonth) {
      textColor = NocturneColors.neutral800;
    } else if (isWeekend) {
      textColor = NocturneColors.neutral500;
    } else {
      textColor = NocturneColors.text;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? NocturneColors.accent : Colors.transparent,
              // Always drawn (even transparent) so selecting a day doesn't
              // shift the layout by adding a border where there was none.
              border: Border.all(color: !isToday && isSelected ? NocturneColors.accent : Colors.transparent),
            ),
            child: Text(
              '${date.day}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, decoration: TextDecoration.none).merge(NocturneText.tabularNums).copyWith(color: textColor),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in dotColors.take(5)) ...[
                  Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayLine extends StatelessWidget {
  const _SelectedDayLine({required this.date, required this.eventCount});

  final DateTime date;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final weekday = weekdayNamesPt[date.weekday % 7]; // DateTime.weekday: Mon=1..Sun=7 -> Sun%7=0
    final countText = eventCount == 1 ? '1 evento' : '$eventCount eventos';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${date.day}', style: NocturneText.bigNumberSheet.merge(NocturneText.tabularNums)),
        const SizedBox(width: 12),
        Text('$weekday · $countText', style: TextStyle(fontSize: 17, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums)),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.instance, required this.calendarName});

  final CalendarEventInstance instance;
  final String calendarName;

  @override
  Widget build(BuildContext context) {
    final timeText = instance.event.allDay ? 'Dia inteiro' : _formatTime(instance.event.start);
    return Container(
      padding: NocturneSpacing.compactCardPadding,
      decoration: BoxDecoration(color: NocturneColors.inset, borderRadius: BorderRadius.circular(NocturneRadii.insetPanel)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 34, decoration: BoxDecoration(color: instance.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instance.event.summary,
                  style: TextStyle(fontSize: 16, color: NocturneColors.text, decoration: TextDecoration.none),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeText · $calendarName',
                  style: TextStyle(fontSize: 13, color: NocturneColors.neutral500, decoration: TextDecoration.none).merge(NocturneText.tabularNums),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 16, color: NocturneColors.neutral600, decoration: TextDecoration.none));
  }
}
