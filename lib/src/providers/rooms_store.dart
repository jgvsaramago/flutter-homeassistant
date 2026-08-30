import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One room card on the Divisões page — a household picks its own rooms and
/// wires each one to whatever real HA entities it has (all optional; an
/// unset field just means that room shows no reading/icon for it, same
/// convention as every other entity config in this app). No entity ids are
/// baked in by default: this app has no fixed idea of what rooms exist.
class RoomConfig {
  const RoomConfig({
    required this.name,
    this.temperatureEntityId,
    this.secondaryEntityId,
    this.lightEntityId,
    this.windowEntityId,
    this.climateEntityId,
    this.speakerEntityId,
    this.coverEntityId,
  });

  final String name;

  /// Room temperature — a `sensor.*` entity, shown as the card's hero number.
  final String? temperatureEntityId;

  /// Drives the card's status line — any entity. Interpreted by domain/
  /// device class: humidity/CO₂ sensors get a friendly reading, `lock.*`
  /// gets a locked/unlocked phrase, anything else falls back to its raw
  /// display state. Unset falls back to the cover's own position (if
  /// [coverEntityId] is set), else the line is omitted.
  final String? secondaryEntityId;

  /// `light.*` or `switch.*` — on/off drives the light icon and the
  /// "Luzes" counter/bulk action.
  final String? lightEntityId;

  /// `binary_sensor.*` (door/window) — open/closed drives the window icon
  /// and the "Janelas" counter.
  final String? windowEntityId;

  /// `climate.*` or `switch.*` — on/active drives the A/C icon and the
  /// "AC" counter.
  final String? climateEntityId;

  /// `media_player.*` — playing vs merely on/idle drives the speaker icon's
  /// two lit shades.
  final String? speakerEntityId;

  /// `cover.*` — drives the blinds icon and the "Fechar/Abrir estores" bulk
  /// action.
  final String? coverEntityId;

  RoomConfig copyWith({
    String? name,
    String? temperatureEntityId,
    String? secondaryEntityId,
    String? lightEntityId,
    String? windowEntityId,
    String? climateEntityId,
    String? speakerEntityId,
    String? coverEntityId,
  }) {
    return RoomConfig(
      name: name ?? this.name,
      temperatureEntityId: temperatureEntityId ?? this.temperatureEntityId,
      secondaryEntityId: secondaryEntityId ?? this.secondaryEntityId,
      lightEntityId: lightEntityId ?? this.lightEntityId,
      windowEntityId: windowEntityId ?? this.windowEntityId,
      climateEntityId: climateEntityId ?? this.climateEntityId,
      speakerEntityId: speakerEntityId ?? this.speakerEntityId,
      coverEntityId: coverEntityId ?? this.coverEntityId,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'temperatureEntityId': temperatureEntityId,
    'secondaryEntityId': secondaryEntityId,
    'lightEntityId': lightEntityId,
    'windowEntityId': windowEntityId,
    'climateEntityId': climateEntityId,
    'speakerEntityId': speakerEntityId,
    'coverEntityId': coverEntityId,
  };

  factory RoomConfig.fromJson(Map<String, dynamic> json) => RoomConfig(
    name: json['name'] as String? ?? '',
    temperatureEntityId: json['temperatureEntityId'] as String?,
    secondaryEntityId: json['secondaryEntityId'] as String?,
    lightEntityId: json['lightEntityId'] as String?,
    windowEntityId: json['windowEntityId'] as String?,
    climateEntityId: json['climateEntityId'] as String?,
    speakerEntityId: json['speakerEntityId'] as String?,
    coverEntityId: json['coverEntityId'] as String?,
  );
}

/// Persists the Divisões room list as a single JSON-encoded string — same
/// reasoning as `CalendarEntitiesStore`/`IndividualSensorsStore`: a
/// user-grown list has no fixed set of `shared_preferences` keys to
/// enumerate. Unlike the energy card's 4 device slots, rooms have no fixed
/// physical layout to cap against, so the list is uncapped.
class RoomsStore {
  RoomsStore();

  static const _key = 'rooms_config';

  Future<List<RoomConfig>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(RoomConfig.fromJson).toList();
  }

  Future<void> save(List<RoomConfig> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = rooms.where((r) => r.name.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(valid.map((r) => r.toJson()).toList()));
  }
}
