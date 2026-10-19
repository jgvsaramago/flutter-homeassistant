import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
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
final calendarRangeProvider = FutureProvider.family<List<KEvent>, ({DateTime start, DateTime end})>((ref, range) async {
  ref.watch(calendarRefreshProvider);
  final sources = ref.watch(calendarSourcesProvider);
  if (sources.isEmpty) return const [];
  await ref.watch(entitiesProvider.future);
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

({DateTime start, DateTime end}) weekRange(DateTime monday) => (start: dateOnly(monday), end: addDays(monday, 7));

/// The next holiday from today on, for the header's "Próximo feriado" line.
final nextHolidayProvider = FutureProvider<KEvent?>((ref) async {
  final today = dateOnly(DateTime.now());
  final events = await ref.watch(calendarRangeProvider((start: today, end: addDays(today, 90))).future);
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

/// Creates an event on [source]'s calendar. Times are minutes from
/// midnight on [day]; all-day events span just that day.
Future<void> createKioskEvent(
  WidgetRef ref, {
  required CalendarSource source,
  required String title,
  required DateTime day,
  required bool allDay,
  required int startMinutes,
  required int endMinutes,
  required EventRepeat repeat,
  String location = '',
  String notes = '',
}) async {
  final d = dateOnly(day);
  final event = <String, dynamic>{
    'summary': title,
    'dtstart': allDay ? PtDates.key(d) : _isoLocal(d.add(Duration(minutes: startMinutes))),
    'dtend': allDay ? PtDates.key(addDays(d, 1)) : _isoLocal(d.add(Duration(minutes: endMinutes))),
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
  await ref.read(haWebSocketClientProvider).createCalendarEvent(source.entityId, event);
  ref.read(calendarRefreshProvider.notifier).state++;
}
