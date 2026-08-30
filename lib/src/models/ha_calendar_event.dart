/// One event, as returned by Home Assistant's `/api/calendars/<entity_id>`
/// REST endpoint (there's no websocket command for calendar events, so this
/// is the one model in the app that isn't sourced from `get_states`).
class HaCalendarEvent {
  const HaCalendarEvent({required this.start, required this.end, required this.allDay, required this.summary});

  /// Local wall-clock start. For an all-day event this is midnight on the
  /// event's date — only the date part is meaningful.
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String summary;

  /// HA's calendar REST API nests the actual value under `date` (all-day)
  /// or `dateTime` (timed, with its own UTC offset already attached) —
  /// `.toLocal()` normalizes both to this device's wall-clock time.
  factory HaCalendarEvent.fromJson(Map<String, dynamic> json) {
    final startMap = (json['start'] as Map).cast<String, dynamic>();
    final endMap = (json['end'] as Map?)?.cast<String, dynamic>() ?? startMap;
    DateTime parse(Map<String, dynamic> m) => DateTime.parse((m['dateTime'] ?? m['date']) as String).toLocal();

    return HaCalendarEvent(
      start: parse(startMap),
      end: parse(endMap),
      allDay: startMap.containsKey('date'),
      summary: json['summary'] as String? ?? '',
    );
  }
}
