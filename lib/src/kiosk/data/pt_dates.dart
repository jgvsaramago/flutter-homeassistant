/// pt-PT date/time wording for the kiosk redesign — no `intl` dependency in
/// this app, and the design only ever needs these few fixed forms.
abstract final class PtDates {
  static const months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

  /// Monday-first, matching [DateTime.weekday] - 1.
  static const weekdays = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
  static const weekdaysShort = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
  static const abbr = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const abbrLower = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const abbrTitle = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const letters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  static String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String two(int n) => n.toString().padLeft(2, '0');

  static String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  static String minutes(int m) => '${two(m ~/ 60)}:${two(m % 60)}';

  static int toMinutes(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p.first) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  /// "17 out"
  static String short(DateTime d) => '${d.day} ${months[d.month - 1].substring(0, 3)}';

  /// "Sábado, 17 de outubro"
  static String long(DateTime d) => '${cap(weekdays[d.weekday - 1])}, ${d.day} de ${months[d.month - 1]}';

  /// "sábado, 17 de outubro"
  static String longLower(DateTime d) => '${weekdays[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]}';

  static String monthYear(DateTime d) => '${cap(months[d.month - 1])} ${d.year}';

  static String key(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  static DateTime? parseKey(String k) {
    final p = k.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static int isoWeek(DateTime d) {
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    return 1 + thursday.difference(firstDay).inDays ~/ 7;
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime mondayOf(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Rounded rather than truncated: across a DST change a calendar day is 23
/// or 25 hours long.
int daysBetween(DateTime a, DateTime b) => (dateOnly(b).difference(dateOnly(a)).inHours / 24).round();

/// Decimal comma, as everywhere else in this app.
String ptDec(double v, {int decimals = 1}) => v.toStringAsFixed(decimals).replaceAll('.', ',');

/// "20,8°"
String ptDeg(double? v) => v == null ? '--' : '${ptDec(v)}°';
