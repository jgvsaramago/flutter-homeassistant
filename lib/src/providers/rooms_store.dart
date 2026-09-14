import '../ha_client/ha_websocket_client.dart';
import '../models/ha_area.dart';
import 'settings_json_utils.dart';

/// One room's entity mapping on the Divisões page — the room itself is a
/// real HA area (see [areaId]/`HaArea`), not something typed into this app;
/// this only stores which of the area's devices power each icon/control.
/// All optional — an unset field just means that room shows no reading/icon
/// for it, same convention as every other entity config in this app.
///
/// [climateEntityId] and [coverEntityId] double as the Climatização page's
/// own dynamic entity list: an AC unit card is rendered for every area with
/// a [climateEntityId], a shutter card for every area with a
/// [coverEntityId] — so adding/removing either on that page is just editing
/// this mapping. Temperature/humidity are *not* stored here at all: they
/// come straight from the area's own sensors (`HaArea.temperatureEntityId`/
/// `humidityEntityId`, set in HA's own Areas & Zones settings), which also
/// feed the Climatização page's per-floor stat tiles.
class RoomConfig {
  const RoomConfig({
    required this.areaId,
    this.secondaryEntityId,
    this.lightEntityId,
    this.windowEntityId,
    this.climateEntityId,
    this.speakerEntityId,
    this.coverEntityId,
  });

  /// The HA area this room mirrors (`HaArea.areaId`) — the room's identity;
  /// its display name/floor/temperature/humidity always come live from the
  /// matching `HaArea`, never stored here.
  final String areaId;

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
  /// action, and doubles as one shutter card on the Climatização page.
  final String? coverEntityId;

  RoomConfig copyWith({
    String? areaId,
    String? secondaryEntityId,
    String? lightEntityId,
    String? windowEntityId,
    String? climateEntityId,
    String? speakerEntityId,
    String? coverEntityId,
  }) {
    return RoomConfig(
      areaId: areaId ?? this.areaId,
      secondaryEntityId: secondaryEntityId ?? this.secondaryEntityId,
      lightEntityId: lightEntityId ?? this.lightEntityId,
      windowEntityId: windowEntityId ?? this.windowEntityId,
      climateEntityId: climateEntityId ?? this.climateEntityId,
      speakerEntityId: speakerEntityId ?? this.speakerEntityId,
      coverEntityId: coverEntityId ?? this.coverEntityId,
    );
  }

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'secondaryEntityId': secondaryEntityId,
    'lightEntityId': lightEntityId,
    'windowEntityId': windowEntityId,
    'climateEntityId': climateEntityId,
    'speakerEntityId': speakerEntityId,
    'coverEntityId': coverEntityId,
  };

  factory RoomConfig.fromJson(Map<String, dynamic> json) => RoomConfig(
    areaId: json['areaId'] as String? ?? '',
    secondaryEntityId: json['secondaryEntityId'] as String?,
    lightEntityId: json['lightEntityId'] as String?,
    windowEntityId: json['windowEntityId'] as String?,
    climateEntityId: json['climateEntityId'] as String?,
    speakerEntityId: json['speakerEntityId'] as String?,
    coverEntityId: json['coverEntityId'] as String?,
  );
}

/// Persists the Divisões entity mappings via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same mapping.
class RoomsStore {
  RoomsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'rooms';

  /// [areas] is the *current* HA area list, needed for two things: dropping
  /// a mapping whose area no longer exists (renamed/deleted in HA since it
  /// was configured), and migrating a pre-Area-picker save — back when a
  /// room was a free-typed `name` rather than a real `areaId` — onto
  /// whichever current area has a matching name. A room that can't be
  /// matched either way is dropped; there's nothing left to key it by once
  /// its area is gone.
  Future<List<RoomConfig>> read(List<HaArea> areas) async {
    final raw = await _client.getSettings(_key);
    if (raw is! List) return const [];

    final areaIds = {for (final a in areas) a.areaId};
    final areaIdByLowerName = {for (final a in areas) a.name.trim().toLowerCase(): a.areaId};

    final result = <RoomConfig>[];
    for (final entry in raw.cast<Map<String, dynamic>>()) {
      var config = RoomConfig.fromJson(entry);
      if (config.areaId.isEmpty) {
        final legacyName = (entry['name'] as String?)?.trim().toLowerCase();
        final matchedId = legacyName == null || legacyName.isEmpty ? null : areaIdByLowerName[legacyName];
        if (matchedId == null) continue;
        config = config.copyWith(areaId: matchedId);
      } else if (!areaIds.contains(config.areaId)) {
        continue;
      }
      result.add(config);
    }
    return result;
  }

  Future<void> save(List<RoomConfig> rooms) async {
    await _client.setSettings(_key, blankStringsToNull(rooms.map((r) => r.toJson()).toList()));
  }
}
