import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import '../../utils/optimistic.dart';
import 'family_data.dart';
import 'pt_dates.dart';

/// One calendar event, tagged with the [source] it came from (whose name
/// and colour it's drawn with).
class KEvent {
  const KEvent({required this.title, required this.start, required this.end, required this.allDay, required this.source});

  final String title;
  final DateTime start;

  /// Exclusive, as HA reports it — an all-day event on the 17th ends at
  /// midnight on the 18th.
  final DateTime end;
  final bool allDay;
  final CalendarSource source;

  /// The last calendar day an all-day event covers.
  DateTime get lastDay {
    final last = addDays(dateOnly(end), -1);
    return last.isBefore(dateOnly(start)) ? dateOnly(start) : last;
  }

  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    if (allDay) return !d.isBefore(dateOnly(start)) && !d.isAfter(lastDay);
    final dayEnd = addDays(d, 1);
    return start.isBefore(dayEnd) && end.isAfter(d);
  }

  /// Start hour as a fractional number on [day] (0 if it began earlier).
  double startHourOn(DateTime day) => start.isBefore(dateOnly(day)) ? 0 : start.hour + start.minute / 60;

  double endHourOn(DateTime day) => end.isAfter(addDays(dateOnly(day), 1)) ? 24 : end.hour + end.minute / 60;

  String get timeRange => '${PtDates.hm(start)} – ${PtDates.hm(end)}';
}

/// Google's Portugal holiday calendar reports English names (and a few
/// observances that aren't days off). Known names are translated; known
/// observances are dropped from the holiday bands entirely.
const _holidayNames = {
  "New Year's Day": 'Ano Novo',
  'Carnival': 'Carnaval',
  'Carnival Tuesday': 'Carnaval',
  'Good Friday': 'Sexta-feira Santa',
  'Easter Sunday': 'Páscoa',
  'Liberty Day': 'Dia da Liberdade',
  'Freedom Day': 'Dia da Liberdade',
  'Labour Day': 'Dia do Trabalhador',
  'Labor Day': 'Dia do Trabalhador',
  'Portugal Day': 'Dia de Portugal',
  'Corpus Christi': 'Corpo de Deus',
  "Saint Anthony's Day": 'Santo António',
  'Assumption Day': 'Assunção de Nossa Senhora',
  'Assumption of Mary': 'Assunção de Nossa Senhora',
  'Republic Day': 'Implantação da República',
  'Implantation of the Republic': 'Implantação da República',
  "All Saints' Day": 'Todos-os-Santos',
  'Restoration of Independence': 'Restauração da Independência',
  'Feast of the Immaculate Conception': 'Imaculada Conceição',
  'Immaculate Conception': 'Imaculada Conceição',
  'Christmas Day': 'Natal',
};

const _notHolidays = {
  'Daylight Saving Time starts',
  'Daylight Saving Time ends',
  'Christmas Eve',
  "New Year's Eve",
  "Mother's Day",
  "Father's Day",
  "Valentine's Day",
  'Ash Wednesday',
  'Palm Sunday',
  'Maundy Thursday',
  'Holy Saturday',
};

/// Bumped every few minutes by the shell and right after the kiosk itself
/// creates an event — every [calendarRangeProvider] watches it, so all
/// cached ranges refetch on their next read.
final calendarRefreshProvider = StateProvider<int>((ref) => 0);

/// Every event from every [calendarSourcesProvider] calendar overlapping
/// [range] (end exclusive). A calendar that fails to load is skipped rather
/// than failing the whole range.
final _calendarFetchProvider = FutureProvider.family<List<KEvent>, ({DateTime start, DateTime end})>((ref, range) async {
  ref.watch(calendarRefreshProvider);
  final sources = ref.watch(calendarSourcesProvider);
  if (sources.isEmpty) return const [];
  await haReady(ref);
  final client = ref.read(haWebSocketClientProvider);

  final perSource = await Future.wait([
    for (final s in sources) client.getCalendarEvents(s.entityId, start: range.start, end: range.end).then((v) => v, onError: (_) => const <Never>[]),
  ]);

  final out = <KEvent>[];
  for (var i = 0; i < sources.length; i++) {
    final source = sources[i];
    for (final e in perSource[i]) {
      var title = e.summary.trim();
      if (source.holiday) {
        if (_notHolidays.contains(title)) continue;
        title = _holidayNames[title] ?? title;
      }
      out.add(KEvent(title: title, start: e.start, end: e.end, allDay: e.allDay, source: source));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
});

/// Events this screen just created that HA hasn't listed back yet.
final _pendingEventsProvider = StateProvider<List<KEvent>>((ref) => const []);

/// [range]'s events as the screen shows them: HA's, plus any just created
/// here and still on their way.
final calendarRangeProvider = Provider.family<AsyncValue<List<KEvent>>, ({DateTime start, DateTime end})>((ref, range) {
  final fetched = ref.watch(_calendarFetchProvider(range));
  final pending = ref.watch(_pendingEventsProvider);
  if (pending.isEmpty) return fetched;
  return fetched.whenData((events) {
    final extra = [
      for (final p in pending)
        if (p.start.isBefore(range.end) && p.end.isAfter(range.start) && !events.any((e) => _sameEvent(e, p))) p,
    ];
    if (extra.isEmpty) return events;
    return [...events, ...extra]..sort((a, b) => a.start.compareTo(b.start));
  });
});

bool _sameEvent(KEvent a, KEvent b) => a.source.entityId == b.source.entityId && a.title == b.title && a.start == b.start;

({DateTime start, DateTime end}) weekRange(DateTime monday) => (start: dateOnly(monday), end: addDays(monday, 7));

/// The next holiday from today on, for the header's "Próximo feriado" line.
final nextHolidayProvider = FutureProvider<KEvent?>((ref) async {
  final today = dateOnly(DateTime.now());
  final events = await ref.watch(_calendarFetchProvider((start: today, end: addDays(today, 90))).future);
  for (final e in events) {
    if (e.source.holiday && !e.lastDay.isBefore(today)) return e;
  }
  return null;
});

enum EventRepeat { none, daily, weekly, monthly }

String _offset(DateTime d) {
  final o = d.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final m = o.inMinutes.abs();
  return '$sign${PtDates.two(m ~/ 60)}:${PtDates.two(m % 60)}';
}

String _isoLocal(DateTime d) => '${PtDates.key(d)}T${PtDates.two(d.hour)}:${PtDates.two(d.minute)}:00${_offset(d)}';

/// Creates an event on [source]'s calendar, from [day] to [endDay] (the
/// same day when null). Times are minutes from midnight on their own day;
/// an all-day event covers every day from [day] to [endDay] inclusive.
///
/// The event shows on the calendars at once; it goes away again if HA
/// rejects it (the error is rethrown) or doesn't list it back. Takes the
/// container, not a widget's ref, since the modal closes straight away.
Future<void> createKioskEvent(
  ProviderContainer container, {
  required CalendarSource source,
  required String title,
  required DateTime day,
  DateTime? endDay,
  required bool allDay,
  required int startMinutes,
  required int endMinutes,
  required EventRepeat repeat,
  String location = '',
  String notes = '',
}) async {
  final d = dateOnly(day);
  final e = dateOnly(endDay ?? day);
  final event = <String, dynamic>{
    'summary': title,
    'dtstart': allDay ? PtDates.key(d) : _isoLocal(d.add(Duration(minutes: startMinutes))),
    'dtend': allDay ? PtDates.key(addDays(e, 1)) : _isoLocal(e.add(Duration(minutes: endMinutes))),
    if (location.isNotEmpty) 'location': location,
    if (notes.isNotEmpty) 'description': notes,
    if (repeat != EventRepeat.none)
      'rrule': switch (repeat) {
        EventRepeat.daily => 'FREQ=DAILY',
        EventRepeat.weekly => 'FREQ=WEEKLY',
        EventRepeat.monthly => 'FREQ=MONTHLY',
        EventRepeat.none => '',
      },
  };
  final shown = KEvent(
    title: title,
    start: allDay ? d : d.add(Duration(minutes: startMinutes)),
    end: allDay ? addDays(e, 1) : e.add(Duration(minutes: endMinutes)),
    allDay: allDay,
    source: source,
  );
  final pending = container.read(_pendingEventsProvider.notifier);
  pending.state = [...pending.state, shown];
  try {
    await container.read(haWebSocketClientProvider).createCalendarEvent(source.entityId, event).timeout(const Duration(seconds: 8));
    container.read(calendarRefreshProvider.notifier).state++;
    final day0 = dateOnly(shown.start);
    final listed = await container.read(_calendarFetchProvider((start: day0, end: addDays(day0, 1))).future).timeout(const Duration(seconds: 8));
    if (!listed.any((x) => _sameEvent(x, shown))) OptimisticLayer.onNotConfirmed?.call('O Home Assistant não confirmou o evento "$title"');
  } on TimeoutException {
    OptimisticLayer.onNotConfirmed?.call('O Home Assistant não confirmou o evento "$title"');
  } finally {
    pending.state = pending.state.where((x) => !identical(x, shown)).toList();
  }
}
