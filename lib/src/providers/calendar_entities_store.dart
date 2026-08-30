import 'package:flutter/material.dart';

import '../ha_client/ha_websocket_client.dart';
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

/// Persists the configured calendar list via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same calendars.
class CalendarEntitiesStore {
  CalendarEntitiesStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'calendar_entities';

  Future<List<CalendarEntryConfig>> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>().map(CalendarEntryConfig.fromJson).toList();
  }

  Future<void> save(List<CalendarEntryConfig> entries) async {
    final valid = entries.where((e) => e.entityId.trim().isNotEmpty).toList();
    await _client.setSettings(_key, valid.map((e) => e.toJson()).toList());
  }
}
