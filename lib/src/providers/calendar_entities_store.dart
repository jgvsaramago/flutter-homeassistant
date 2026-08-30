import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/nocturne_theme.dart';

/// The palette a calendar entry can be assigned. Deliberately capped at the
/// five hues Nocturne's theme actually defines (see `NocturneColors`) rather
/// than an arbitrary colour wheel — resolving a token, never inventing a
/// hex, is the same rule the sheet's dots and chips follow. With more than
/// five configured calendars, colours repeat; the calendar's name in the
/// chip and event list is what disambiguates then, never colour alone.
enum CalendarColorKey { accent, blue, green, amber, red }

extension CalendarColorKeyStyle on CalendarColorKey {
  Color get color => switch (this) {
    CalendarColorKey.accent => NocturneColors.accent,
    CalendarColorKey.blue => NocturneColors.blue,
    CalendarColorKey.green => NocturneColors.green,
    CalendarColorKey.amber => NocturneColors.amber,
    CalendarColorKey.red => NocturneColors.red,
  };

  String get label => switch (this) {
    CalendarColorKey.accent => 'Roxo',
    CalendarColorKey.blue => 'Azul',
    CalendarColorKey.green => 'Verde',
    CalendarColorKey.amber => 'Âmbar',
    CalendarColorKey.red => 'Vermelho',
  };
}

/// One calendar the app should read events from, and the colour it draws in
/// the calendar card/sheet — a household picks the entity from its own HA
/// instance (this app has no calendar wired in by default, unlike the
/// weather/energy entities which have a working household default).
class CalendarEntryConfig {
  const CalendarEntryConfig({required this.entityId, required this.color});

  final String entityId;
  final CalendarColorKey color;

  CalendarEntryConfig copyWith({String? entityId, CalendarColorKey? color}) =>
      CalendarEntryConfig(entityId: entityId ?? this.entityId, color: color ?? this.color);

  Map<String, dynamic> toJson() => {'entityId': entityId, 'color': color.name};

  factory CalendarEntryConfig.fromJson(Map<String, dynamic> json) => CalendarEntryConfig(
    entityId: json['entityId'] as String,
    color: CalendarColorKey.values.firstWhere((c) => c.name == json['color'], orElse: () => CalendarColorKey.accent),
  );
}

/// Persists the configured calendar list as a single JSON-encoded string —
/// unlike the other entity configs (fixed named fields), this one is a
/// user-grown list, so there's no fixed set of `shared_preferences` keys to
/// enumerate.
class CalendarEntitiesStore {
  CalendarEntitiesStore();

  static const _key = 'calendar_entries';

  Future<List<CalendarEntryConfig>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(CalendarEntryConfig.fromJson).toList();
  }

  Future<void> save(List<CalendarEntryConfig> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = entries.where((e) => e.entityId.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(valid.map((e) => e.toJson()).toList()));
  }
}
