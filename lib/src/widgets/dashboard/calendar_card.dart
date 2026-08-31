import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_events_provider.dart';
import '../../sheets/dashboard/calendar_sheet.dart';
import '../../theme/nocturne_theme.dart';
import 'calendar_grid.dart';

class _CalendarDay {
  const _CalendarDay({required this.date, required this.isToday, required this.isCurrentMonth, required this.dotColors});
  final DateTime date;
  final bool isToday;
  final bool isCurrentMonth;
  final List<Color> dotColors;
}

/// Left half of section 6: a real calendar grid (month/today derived from
/// the system clock) with event dots from the calendars configured in
/// Definições → Calendário. Tapping anywhere on the card opens the full
/// Calendar sheet.
class CalendarCard extends ConsumerWidget {
  const CalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthAnchor = monthAnchorForOffset(now, 0);
    // `.valueOrNull`, not `.value` — `AsyncValue.value` rethrows the
    // underlying error when the provider has errored and never had a prior
    // value (e.g. the calendar REST fetch failing, whether from a CORS
    // block on web or HA being briefly unreachable), which would crash this
    // whole card into a release-mode grey error box instead of just
    // showing an empty grid.
    final eventsByDate = groupByDate(ref.watch(calendarMonthEventsProvider(monthAnchor)).valueOrNull ?? const []);

    final grid = buildMonthGrid(monthAnchor);
    final days = [
      for (final date in grid)
        _CalendarDay(
          date: date,
          isToday: date == dateOnly(now),
          isCurrentMonth: date.month == now.month,
          dotColors: [for (final instance in eventsByDate[date] ?? const []) instance.color],
        ),
    ];
    final monthLabel = '${monthNamesPt[now.month - 1]} de ${now.year}';

    return SizedBox(
      width: 333,
      height: 336,
      child: Card(
        child: InkWell(
          onTap: () => showCalendarSheet(context),
          borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
          child: Padding(
            padding: NocturneSpacing.cardPadding,
            child: Column(
              children: [
                Text(monthLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < weekdayInitialsPt.length; i++)
                      Expanded(
                        child: Text(
                          weekdayInitialsPt[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: i == 0 || i == 6 ? NocturneColors.neutral700 : NocturneColors.neutral600),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellWidth = constraints.maxWidth / 7;
                      final cellHeight = constraints.maxHeight / 6;
                      return GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 7,
                        childAspectRatio: cellWidth / cellHeight,
                        children: [for (final day in days) _DayCell(day: day)],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final _CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final textColor = day.isToday
        ? NocturneColors.bg
        : day.isCurrentMonth
        ? NocturneColors.text
        : NocturneColors.neutral800;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: day.isToday ? NocturneColors.accent : Colors.transparent,
          ),
          child: Text('${day.date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in day.dotColors.take(4)) ...[
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
