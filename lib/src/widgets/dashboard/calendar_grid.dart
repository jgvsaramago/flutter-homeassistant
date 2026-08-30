/// Date/grid helpers shared by the calendar card and the calendar sheet, so
/// the two can never disagree about which 42 days a given month shows.
library;

const monthNamesPt = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Sunday-first, matching this app's data source convention.
const weekdayInitialsPt = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

const weekdayNamesPt = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first-of-month anchor for "today shifted by [offset] months" — Dart's
/// `DateTime` constructor normalizes an out-of-range month on its own, so
/// `offset` can be any integer without extra bookkeeping.
DateTime monthAnchorForOffset(DateTime today, int offset) => DateTime(today.year, today.month + offset);

/// The Sunday on or before [monthAnchor]'s 1st — the first of the fixed 42
/// cells every calendar grid in this app renders.
DateTime monthGridStart(DateTime monthAnchor) {
  final first = DateTime(monthAnchor.year, monthAnchor.month, 1);
  return first.subtract(Duration(days: first.weekday % 7)); // DateTime.weekday: Mon=1..Sun=7
}

/// The 42 dates (date-only) a month's fixed-size grid renders, starting from
/// [monthGridStart].
List<DateTime> buildMonthGrid(DateTime monthAnchor) {
  final start = monthGridStart(monthAnchor);
  return [for (var i = 0; i < 42; i++) start.add(Duration(days: i))];
}

int daysInMonth(DateTime monthAnchor) => DateTime(monthAnchor.year, monthAnchor.month + 1, 0).day;
