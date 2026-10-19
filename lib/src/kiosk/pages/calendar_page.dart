import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar_data.dart';
import '../data/family_data.dart';
import '../data/pt_dates.dart';
import '../modals/event_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_header.dart';
import '../widgets/kiosk_widgets.dart';

enum CalView {
  day('Dia'),
  week('Semana'),
  month('Mês'),
  agenda('Agenda');

  const CalView(this.label);

  final String label;
}

/// Where the Calendário should open next — set by Início when a day is
/// tapped, consumed (and cleared) by the page.
final calendarFocusProvider = StateProvider<({DateTime date, CalView view})?>((ref) => null);

/// Remembered across visits within a session, like a real calendar app.
final _calViewProvider = StateProvider<CalView>((ref) => CalView.week);

const _hourHeight = 96.0;

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _anchor = dateOnly(DateTime.now());
  final Set<String> _hidden = {};
  int _navDir = 0;
  int _navTick = 0;

  @override
  void initState() {
    super.initState();
    final focus = ref.read(calendarFocusProvider);
    if (focus != null) {
      _anchor = dateOnly(focus.date);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_calViewProvider.notifier).state = focus.view;
        ref.read(calendarFocusProvider.notifier).state = null;
      });
    }
  }

  void _setView(CalView v) {
    ref.read(_calViewProvider.notifier).state = v;
    setState(() {
      _navDir = 0;
      _navTick++;
    });
  }

  void _shift(int dir) {
    final view = ref.read(_calViewProvider);
    setState(() {
      _anchor = switch (view) {
        CalView.month => DateTime(_anchor.year, _anchor.month + dir, 1),
        CalView.day => addDays(_anchor, dir),
        _ => addDays(_anchor, dir * 7),
      };
      _navDir = dir;
      _navTick++;
    });
  }

  void _openDay(DateTime d) {
    ref.read(_calViewProvider.notifier).state = CalView.day;
    setState(() {
      _anchor = dateOnly(d);
      _navDir = 0;
      _navTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(_calViewProvider);
    final now = watchNow(ref);
    final sources = ref.watch(calendarSourcesProvider);
    final monday = mondayOf(_anchor);
    final sunday = addDays(monday, 6);

    final (String title, String sub) = switch (view) {
      CalView.day => (PtDates.long(_anchor), '${sameDay(_anchor, now) ? 'Hoje · ' : ''}${_anchor.year} · Semana ${PtDates.isoWeek(_anchor)}'),
      CalView.week => (
        monday.month == sunday.month
            ? PtDates.monthYear(monday)
            : '${PtDates.cap(PtDates.months[monday.month - 1])} – ${PtDates.months[sunday.month - 1]} ${sunday.year}',
        'Semana ${PtDates.isoWeek(monday)} · ${PtDates.short(monday)} – ${PtDates.short(sunday)}',
      ),
      CalView.month => (PtDates.monthYear(_anchor), 'Toque num dia para ver o detalhe'),
      CalView.agenda => ('Agenda', 'Próximas 3 semanas, a partir de ${PtDates.weekdays[_anchor.weekday - 1]}, ${PtDates.short(_anchor)}'),
    };

    final range = switch (view) {
      CalView.week => weekRange(monday),
      CalView.agenda => (start: _anchor, end: addDays(_anchor, 21)),
      _ => _monthGridRange(_anchor),
    };
    final all = ref.watch(calendarRangeProvider(range)).valueOrNull ?? const <KEvent>[];
    final events = all.where((e) => !_hidden.contains(e.source.entityId)).toList();

    final body = switch (view) {
      CalView.week => _WeekView(monday: monday, events: events, now: now, onDay: _openDay),
      CalView.day => _DayView(day: _anchor, events: events, now: now, onDay: _openDay, hidden: _hidden),
      CalView.month => _MonthView(anchor: _anchor, events: events, now: now, onDay: _openDay),
      CalView.agenda => _AgendaView(start: _anchor, events: events, now: now),
    };

    return KSection(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.pageTitle),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: KText.s(20, weight: FontWeight.w500, color: KColors.muted),
                    ),
                  ],
                ),
              ),
              KCircleButton(icon: KIcons.chevronLeft, onTap: () => _shift(-1)),
              const SizedBox(width: 12),
              KCircleButton(icon: KIcons.chevronRight, onTap: () => _shift(1)),
              const SizedBox(width: 12),
              KButton(
                label: 'Hoje',
                onTap: () => setState(() {
                  _anchor = dateOnly(now);
                  _navDir = 0;
                  _navTick++;
                }),
              ),
              const SizedBox(width: 12),
              KButton.primary(
                label: 'Novo evento',
                icon: KIcons.plus,
                onTap: () async {
                  final d = await showEventModal(context, day: view == CalView.day || _anchor.isAfter(now) ? _anchor : now);
                  if (d != null && mounted) setState(() => _anchor = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: KColors.chip, borderRadius: BorderRadius.circular(40)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final v in CalView.values) ...[
                      if (v != CalView.day) const SizedBox(width: 4),
                      KChip(label: v.label, on: v == view, height: 60, padX: 24, offBg: Colors.transparent, onTap: () => _setView(v)),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in sources)
                    () {
                      final hide = _hidden.contains(s.entityId);
                      return KPress(
                        onTap: () => setState(() => hide ? _hidden.remove(s.entityId) : _hidden.add(s.entityId)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 64,
                          padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
                          decoration: BoxDecoration(
                            color: hide ? Colors.white : s.color.tint,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: hide ? KColors.border : s.color.tint, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KAvatar(initial: s.initial, color: hide ? KColors.disabledFg : s.color.color, size: 46, flag: s.holiday),
                              const SizedBox(width: 12),
                              Text(
                                s.name,
                                style: KText.s(22, weight: FontWeight.w600, color: hide ? KColors.muted : KColors.ink),
                              ),
                            ],
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_navTick),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 340),
              curve: kEase,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: _navDir == 0 ? Offset(0, 16 * (1 - t)) : Offset(48 * _navDir * (1 - t), 0), child: child),
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

({DateTime start, DateTime end}) _monthGridRange(DateTime anchor) {
  final first = DateTime(anchor.year, anchor.month, 1);
  final start = mondayOf(first);
  final days = DateTime(anchor.year, anchor.month + 1, 0).day;
  final rows = ((first.weekday - 1 + days) / 7).ceil();
  return (start: start, end: addDays(start, rows * 7));
}

bool _isHoliday(List<KEvent> events, DateTime d) => events.any((e) => e.source.holiday && e.allDay && e.coversDay(d));

// ─── Timeline (week + day) ─────────────────────────────────────────────

class _Placed {
  const _Placed(this.e, this.top, this.height, this.left, this.z);

  final KEvent e;
  final double top, height, left;
  final int z;
}

/// The design's overlap rule: the shorter event sits on top of the longer
/// one, indented so the one underneath still shows.
List<_Placed> _place(List<KEvent> events, DateTime day, int h0, {double indent = 10}) {
  final spans = [for (final e in events) (e: e, a: e.startHourOn(day), b: e.endHourOn(day))]..sort((x, y) => (y.b - y.a).compareTo(x.b - x.a));
  return [
    for (final (i, s) in spans.indexed)
      _Placed(
        s.e,
        (s.a - h0) * _hourHeight + 2,
        math.max(44, (s.b - s.a) * _hourHeight - 4),
        4 + indent * spans.take(i).where((o) => o.a < s.b && s.a < o.b).length,
        i,
      ),
  ];
}

int _firstHour(List<KEvent> timed) {
  var h = 7;
  for (final e in timed) {
    if (!e.allDay && e.start.hour < h && sameDay(e.start, e.end)) h = e.start.hour;
  }
  return h;
}

class _HourGrid extends StatelessWidget {
  const _HourGrid({required this.h0, required this.child});

  final int h0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hours = 24 - h0;
    return SizedBox(
      height: hours * _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var h = 0; h < hours; h++)
                  Positioned(
                    top: h * _hourHeight - 10,
                    left: 0,
                    child: Text(
                      '${PtDates.two(h0 + h)}:00',
                      style: KText.s(16, weight: FontWeight.w500, color: KColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                for (var h = 0; h < hours; h++)
                  Positioned(
                    top: h * _hourHeight,
                    left: 0,
                    right: 0,
                    child: Container(height: 1.5, color: KColors.divider),
                  ),
                Positioned.fill(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top - 7,
    left: -7,
    right: 0,
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(color: KColors.now, shape: BoxShape.circle),
        ),
        Expanded(child: Container(height: 2.5, color: KColors.now)),
      ],
    ),
  );
}

class _TimedBlock extends StatelessWidget {
  const _TimedBlock({required this.p, this.large = false});

  final _Placed p;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final e = p.e;
    final c = e.source.color;
    final long = p.height >= _hourHeight - 4;
    return Container(
      padding: large ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12) : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(large ? 16 : 14),
        border: Border.all(color: Colors.white, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      e.timeRange,
                      style: KText.s(18, weight: FontWeight.w700, color: c.ink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.s(24, weight: FontWeight.w600, height: 1.2),
                      ),
                    ),
                  ],
                ),
                if (long) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      KAvatar(initial: e.source.initial, color: c.color, size: 30, fontSize: 14),
                      const SizedBox(width: 10),
                      Text(e.source.name, style: KText.s(18, color: KColors.ink3)),
                    ],
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.timeRange,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: KText.s(15, weight: FontWeight.w700, color: c.ink),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    e.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: long ? 3 : 1,
                    style: KText.s(19, weight: FontWeight.w600, height: 1.2),
                  ),
                ),
                if (long && p.height > 150) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.s(15, color: KColors.ink3),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _AllDayPill extends StatelessWidget {
  const _AllDayPill({required this.e, this.fontSize = 19, this.range = ''});

  final KEvent e;
  final double fontSize;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: e.source.color.color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          if (e.source.holiday) ...[const KIcon(KIcons.flag, size: 22, color: Colors.white, stroke: 2.2), const SizedBox(width: 10)],
          Flexible(
            child: Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.s(fontSize, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
          if (range.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              range,
              maxLines: 1,
              style: KText.s(fontSize - 3, weight: FontWeight.w500, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

String _spanRange(KEvent e) {
  final a = dateOnly(e.start), b = e.lastDay;
  if (sameDay(a, b)) return '';
  return a.month == b.month ? '${a.day} – ${PtDates.short(b)}' : '${PtDates.short(a)} – ${PtDates.short(b)}';
}

class _FreeDay extends StatelessWidget {
  const _FreeDay({this.big = false});

  final bool big;

  @override
  Widget build(BuildContext context) {
    if (!big) {
      return Column(
        children: [
          const KIcon(KIcons.calendarCheck, size: 34, color: KColors.faint2, stroke: 1.8),
          const SizedBox(height: 12),
          Text(
            'Dia livre',
            style: KText.s(18, weight: FontWeight.w600, color: KColors.muted),
          ),
        ],
      );
    }
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: const BoxDecoration(color: KColors.chip, shape: BoxShape.circle),
          child: const Center(child: KIcon(KIcons.calendarCheck, size: 60, color: KColors.muted, stroke: 1.6)),
        ),
        const SizedBox(height: 18),
        Text('Nada agendado', style: KText.d(38)),
        const SizedBox(height: 18),
        Text('Este dia está livre.', style: KText.s(22, color: KColors.muted)),
      ],
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.monday, required this.events, required this.now, required this.onDay});

  final DateTime monday;
  final List<KEvent> events;
  final DateTime now;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final timed = events.where((e) => !e.allDay).toList();
    final h0 = _firstHour(timed);

    // All-day band: each event (clipped to this week) in the first lane
    // where it fits.
    final lanes = <List<(int, int, KEvent)>>[];
    for (final e in events.where((e) => e.allDay)) {
      final from = math.max(0, daysBetween(monday, e.start));
      final to = math.min(6, daysBetween(monday, e.lastDay));
      if (to < 0 || from > 6) continue;
      final lane = lanes.indexWhere((l) => l.every((x) => x.$2 < from || x.$1 > to));
      if (lane < 0) {
        lanes.add([(from, to, e)]);
      } else {
        lanes[lane].add((from, to, e));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 72),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: KPress(
                    onTap: () => onDay(d),
                    child: _DayHeader(day: d, today: sameDay(d, now), holiday: _isHoliday(events, d)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: KColors.divider, width: 1.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 52,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DIA\nTODO',
                    style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1, height: 1.1),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final col = c.maxWidth / 7;
                    return SizedBox(
                      height: math.max(1, lanes.length) * 60 - 8,
                      child: Stack(
                        children: [
                          for (final (li, lane) in lanes.indexed)
                            for (final (from, to, e) in lane)
                              Positioned(
                                left: from * col + 3,
                                width: (to - from + 1) * col - 6,
                                top: li * 60.0,
                                child: _AllDayPill(e: e, range: _spanRange(e)),
                              ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 10),
            child: _HourGrid(
              h0: h0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: sameDay(d, now) ? KColors.todayBg : (_isHoliday(events, d) ? KColors.holidayBg : null),
                          border: const Border(left: BorderSide(color: KColors.divider, width: 1.5)),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final p in _place(timed.where((e) => e.coversDay(d)).toList(), d, h0)..sort((a, b) => a.z.compareTo(b.z)))
                              Positioned(
                                top: p.top,
                                height: p.height,
                                left: p.left,
                                right: 4,
                                child: _TimedBlock(p: p),
                              ),
                            if (!events.any((e) => e.coversDay(d))) const Positioned(top: 380, left: 0, right: 0, child: _FreeDay()),
                            if (sameDay(d, now)) _NowLine(top: (now.hour + now.minute / 60 - h0) * _hourHeight),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today, required this.holiday});

  final DateTime day;
  final bool today;
  final bool holiday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          PtDates.abbr[day.weekday - 1],
          style: KText.s(18, weight: FontWeight.w700, spacing: 1.5, color: holiday ? KColors.red : (today ? KColors.todayInk : KColors.muted)),
        ),
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: today ? KColors.accent : (holiday ? KColors.redTint : Colors.transparent), shape: BoxShape.circle),
          child: Text('${day.day}', style: KText.d(32, color: today ? Colors.white : (holiday ? KColors.redInk : KColors.ink))),
        ),
      ],
    );
  }
}

class _DayView extends ConsumerWidget {
  const _DayView({required this.day, required this.events, required this.now, required this.onDay, required this.hidden});

  final DateTime day;
  final List<KEvent> events;
  final DateTime now;
  final ValueChanged<DateTime> onDay;
  final Set<String> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDay = events.where((e) => e.allDay && e.coversDay(day)).toList();
    final timed = events.where((e) => !e.allDay && e.coversDay(day)).toList();
    final h0 = _firstHour(timed);
    final today = sameDay(day, now);
    final sources = ref.watch(calendarSourcesProvider).where((s) => !s.holiday && !hidden.contains(s.entityId)).toList();
    final holidays = (ref.watch(calendarRangeProvider((start: dateOnly(day), end: addDays(day, 150)))).valueOrNull ?? const <KEvent>[])
        .where((e) => e.source.holiday)
        .take(3)
        .toList();
    final free = allDay.isEmpty && timed.isEmpty;

    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: child,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                constraints: const BoxConstraints(minHeight: 76),
                decoration: const BoxDecoration(
                  border: Border.symmetric(horizontal: BorderSide(color: KColors.divider, width: 1.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        'DIA\nTODO',
                        style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1, height: 1.1),
                      ),
                    ),
                    Expanded(
                      child: allDay.isEmpty
                          ? Text('Sem eventos de dia inteiro', style: KText.s(19, color: KColors.muted))
                          : Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final e in allDay)
                                  IntrinsicWidth(
                                    child: _AllDayPill(e: e, fontSize: 20, range: _spanRange(e)),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10),
                  child: _HourGrid(
                    h0: h0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: today ? KColors.todayBg : (_isHoliday(events, day) ? KColors.holidayBg : null),
                        border: const Border(left: BorderSide(color: KColors.divider, width: 1.5)),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final p in _place(timed, day, h0, indent: 24)..sort((a, b) => a.z.compareTo(b.z)))
                            Positioned(
                              top: p.top,
                              height: p.height,
                              left: p.left,
                              right: 8,
                              child: _TimedBlock(p: p, large: true),
                            ),
                          if (free) const Positioned(top: 240, left: 0, right: 0, child: _FreeDay(big: true)),
                          if (today) _NowLine(top: (now.hour + now.minute / 60 - h0) * _hourHeight),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 28),
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                panel(_MiniMonth(selected: day, events: events, now: now, onDay: onDay)),
                const SizedBox(height: 20),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Resumo do dia', style: KText.s(22, weight: FontWeight.w600)),
                      for (final s in sources) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            KAvatar(initial: s.initial, color: s.color.color, size: 36, fontSize: 15),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s.name, style: KText.s(20))),
                            () {
                              final n =
                                  timed.where((e) => e.source.entityId == s.entityId).length + allDay.where((e) => e.source.entityId == s.entityId).length;
                              return Text(n == 1 ? '1 evento' : '$n eventos', style: KText.s(20, weight: FontWeight.w600));
                            }(),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (holidays.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const KIcon(KIcons.flag, size: 26, color: KColors.redInk, stroke: 2.2),
                            const SizedBox(width: 10),
                            Text(
                              'Próximos feriados',
                              style: KText.s(22, weight: FontWeight.w600, color: KColors.redInk),
                            ),
                          ],
                        ),
                        for (final h in holidays) ...[
                          const SizedBox(height: 14),
                          Text(
                            '${PtDates.abbr[h.start.weekday - 1]}, ${PtDates.short(h.start).toUpperCase()}',
                            style: KText.s(16, weight: FontWeight.w700, color: KColors.muted, spacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(h.title, style: KText.s(20, weight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.selected, required this.events, required this.now, required this.onDay});

  final DateTime selected;
  final List<KEvent> events;
  final DateTime now;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final r = _monthGridRange(selected);
    final cells = daysBetween(r.start, r.end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(PtDates.monthYear(selected), style: KText.d(28)),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final l in PtDates.letters)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: KText.s(15, weight: FontWeight.w700, color: KColors.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var row = 0; row < cells ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  () {
                    final d = addDays(r.start, row * 7 + col);
                    final sel = sameDay(d, selected), today = sameDay(d, now), inMonth = d.month == selected.month;
                    final has = events.any((e) => e.coversDay(d));
                    final fg = sel ? Colors.white : (!inMonth ? KColors.faint : (_isHoliday(events, d) ? KColors.red : KColors.ink));
                    return Expanded(
                      child: KPress(
                        onTap: () => onDay(d),
                        child: Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: sel ? KColors.accent : (today ? KColors.todayBg : Colors.transparent),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${d.day}',
                                style: KText.s(19, weight: FontWeight.w600, color: fg),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: has ? (sel ? Colors.white : KColors.faint) : Colors.transparent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.anchor, required this.events, required this.now, required this.onDay});

  final DateTime anchor;
  final List<KEvent> events;
  final DateTime now;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final r = _monthGridRange(anchor);
    final rows = daysBetween(r.start, r.end) ~/ 7;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final a in PtDates.abbr)
                Expanded(
                  child: Text(
                    a,
                    textAlign: TextAlign.center,
                    style: KText.s(18, weight: FontWeight.w700, color: KColors.muted, spacing: 1.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 7; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _MonthCell(
                      day: addDays(r.start, row * 7 + col),
                      inMonth: addDays(r.start, row * 7 + col).month == anchor.month,
                      events: events,
                      now: now,
                      onDay: onDay,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day, required this.inMonth, required this.events, required this.now, required this.onDay});

  final DateTime day;
  final bool inMonth;
  final List<KEvent> events;
  final DateTime now;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(day, now);
    final holiday = _isHoliday(events, day);
    final allDay = events.where((e) => e.allDay && e.coversDay(day)).toList();
    final timed = events.where((e) => !e.allDay && e.coversDay(day)).toList();
    final adShown = allDay.take(2).toList();
    final evShown = timed.take(math.max(0, 4 - adShown.length)).toList();
    final more = allDay.length - adShown.length + timed.length - evShown.length;
    return Opacity(
      opacity: inMonth ? 1 : 0.45,
      child: KPress(
        onTap: () => onDay(day),
        child: Container(
          padding: const EdgeInsets.all(10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: today ? KColors.todayBg : (holiday ? KColors.holidayBg : KColors.sub), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: today ? KColors.accent : Colors.transparent, shape: BoxShape.circle),
                  child: Text('${day.day}', style: KText.d(24, color: today ? Colors.white : (holiday ? KColors.red : KColors.ink))),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final a in adShown)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: a.source.color.color, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.s(15, weight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        for (final e in evShown)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: e.source.color.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(PtDates.hm(e.start), style: KText.s(15, weight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(15)),
                                ),
                              ],
                            ),
                          ),
                        if (more > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+$more mais',
                              style: KText.s(15, weight: FontWeight.w600, color: KColors.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({required this.start, required this.events, required this.now});

  final DateTime start;
  final List<KEvent> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(right: 8),
      itemCount: 21,
      itemBuilder: (context, i) {
        final d = addDays(start, i);
        final rel = daysBetween(now, d);
        final holiday = _isHoliday(events, d);
        final allDay = events.where((e) => e.allDay && e.coversDay(d)).toList();
        final timed = events.where((e) => !e.allDay && e.coversDay(d)).toList();
        final label = rel == 0 ? 'Hoje' : (rel == 1 ? 'Amanhã' : '');
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: KColors.divider, width: 1.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${PtDates.abbr[d.weekday - 1]} · ${PtDates.months[d.month - 1].substring(0, 3).toUpperCase()}',
                      style: KText.s(18, weight: FontWeight.w700, spacing: 1.5, color: holiday ? KColors.red : KColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text('${d.day}', style: KText.d(60, height: 1, color: holiday ? KColors.red : KColors.ink)),
                    if (label.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: rel == 0 ? KColors.accent : KColors.chip, borderRadius: BorderRadius.circular(17)),
                        child: Text(
                          label,
                          style: KText.s(16, weight: FontWeight.w700, color: rel == 0 ? Colors.white : KColors.ink),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  children: [
                    for (final e in allDay) _row('Dia todo', e, filled: true),
                    for (final e in timed) _row(e.timeRange, e),
                    if (allDay.isEmpty && timed.isEmpty)
                      KDashedBox(
                        radius: 18,
                        child: Container(
                          height: 76,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              const KIcon(KIcons.calendarCheck, size: 28, color: KColors.muted, stroke: 1.8),
                              const SizedBox(width: 14),
                              Text('Dia livre · nada agendado', style: KText.s(22, color: KColors.muted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String time, KEvent e, {bool filled = false}) {
    final c = e.source.color;
    final fg = filled ? Colors.white : KColors.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: filled ? c.color : c.tint, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              time,
              style: KText.s(20, weight: FontWeight.w700, color: filled ? Colors.white : c.ink),
            ),
          ),
          const SizedBox(width: 20),
          if (e.source.holiday) ...[KIcon(KIcons.flag, size: 26, color: fg, stroke: 2.2), const SizedBox(width: 12)],
          Expanded(
            child: Text(
              e.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.s(24, weight: FontWeight.w600, color: fg),
            ),
          ),
          if (!e.source.holiday) ...[
            const SizedBox(width: 20),
            KAvatar(initial: e.source.initial, color: filled ? const Color(0x38FFFFFF) : c.color, size: 38, fontSize: 16),
            const SizedBox(width: 10),
            Text(e.source.name, style: KText.s(19, color: filled ? Colors.white : KColors.ink3)),
          ],
        ],
      ),
    );
  }
}
