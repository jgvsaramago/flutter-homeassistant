import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ha_calendar_event.dart';
import '../widgets/dashboard/calendar_grid.dart';
import 'calendar_entities_provider.dart';
import 'calendar_entities_store.dart';
import 'ha_providers.dart';

/// One fetched event tagged with which configured calendar it came from —
/// the REST response itself carries no entity id, so the fetch loop attaches
/// it before the per-calendar lists are merged.
class CalendarEventInstance {
  const CalendarEventInstance({required this.event, required this.entityId, required this.color});

  final HaCalendarEvent event;
  final String entityId;
  final Color color;
}

/// Every event from every configured calendar, across the 42-day grid the
/// card/sheet render for [monthAnchor]'s month (not just the calendar month
/// itself, so leading/trailing days from neighbouring months get their dots
/// too). Keyed by [monthAnchor] — Riverpod caches each month's fetch, so
/// paging back and forth doesn't refetch a month already seen this session.
final calendarMonthEventsProvider = FutureProvider.family<List<CalendarEventInstance>, DateTime>((ref, monthAnchor) async {
  final entries = ref.watch(calendarEntriesProvider);
  if (entries.isEmpty) return const [];

  final client = ref.read(haWebSocketClientProvider);
  final start = monthGridStart(monthAnchor);
  final end = start.add(const Duration(days: 42));

  final perCalendar = await Future.wait([for (final entry in entries) client.getCalendarEvents(entry.entityId, start: start, end: end)]);

  return [
    for (var i = 0; i < entries.length; i++)
      for (final event in perCalendar[i]) CalendarEventInstance(event: event, entityId: entries[i].entityId, color: entries[i].color.color),
  ];
});

/// [instances] grouped by every date they touch — the single source both
/// the grid's dot rows and the selected-day event list read from, so a
/// multi-day event (a long weekend, a holiday range) shows consistently on
/// every day it spans rather than only its first.
Map<DateTime, List<CalendarEventInstance>> groupByDate(List<CalendarEventInstance> instances) {
  final byDate = <DateTime, List<CalendarEventInstance>>{};
  for (final instance in instances) {
    final startDate = dateOnly(instance.event.start);
    // HA's all-day `end` is exclusive (a single-day event's end is already
    // the next date), so the last day actually covered is end minus one.
    final rawLastDate = instance.event.allDay ? dateOnly(instance.event.end).subtract(const Duration(days: 1)) : dateOnly(instance.event.end);
    final lastDate = rawLastDate.isBefore(startDate) ? startDate : rawLastDate;

    for (var day = startDate; !day.isAfter(lastDate); day = day.add(const Duration(days: 1))) {
      byDate.putIfAbsent(day, () => []).add(instance);
    }
  }
  return byDate;
}
