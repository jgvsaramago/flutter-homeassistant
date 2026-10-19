import '../ha_client/ha_websocket_client.dart';
import '../models/ha_area.dart';

/// One room's entity mapping for the Casa page's room grid — the room is a
/// real HA area (see [areaId]/`HaArea`), not something typed into this app;
/// this only stores which of the area's devices it shows. All optional.
///
/// [climateEntityId] also makes the room an AC unit in the Clima controls
/// (Início's summary, the Casa page, the AC modal). Temperature/humidity
/// aren't stored here: they come from the area's own sensors in HA.
class RoomConfig {
  const RoomConfig({
    required this.areaId,
    this.secondaryEntityId,
    this.lightEntityId,
    this.windowEntityId,
    this.climateEntityId,
    this.coverEntityId,
  });

  /// The HA area this room mirrors (`HaArea.areaId`) — the room's identity;
  /// its display name/floor/temperature/humidity always come live from the
  /// matching `HaArea`, never stored here.
  final String areaId;

  /// An extra status line on the room's tile — any entity; `lock.*` reads
  /// as locked/open, anything else as its name and state.
  final String? secondaryEntityId;

  /// `light.*` (often a group) or `switch.*` — the tile's light toggle,
  /// and part of "Apagar todas as luzes".
  final String? lightEntityId;

  /// `binary_sensor.*` (door/window) — "Janela aberta/fechadas".
  final String? windowEntityId;

  /// `climate.*` — the room's AC unit.
  final String? climateEntityId;

  /// `cover.*` — the blinds' position line on the tile.
  final String? coverEntityId;

  RoomConfig copyWith({
    String? areaId,
    String? secondaryEntityId,
    String? lightEntityId,
    String? windowEntityId,
    String? climateEntityId,
    String? coverEntityId,
  }) {
    return RoomConfig(
      areaId: areaId ?? this.areaId,
      secondaryEntityId: secondaryEntityId ?? this.secondaryEntityId,
      lightEntityId: lightEntityId ?? this.lightEntityId,
      windowEntityId: windowEntityId ?? this.windowEntityId,
      climateEntityId: climateEntityId ?? this.climateEntityId,
      coverEntityId: coverEntityId ?? this.coverEntityId,
    );
  }

  factory RoomConfig.fromJson(Map<String, dynamic> json) => RoomConfig(
    areaId: json['areaId'] as String? ?? '',
    secondaryEntityId: json['secondaryEntityId'] as String?,
    lightEntityId: json['lightEntityId'] as String?,
    windowEntityId: json['windowEntityId'] as String?,
    climateEntityId: json['climateEntityId'] as String?,
    coverEntityId: json['coverEntityId'] as String?,
  );
}

/// Reads the room mappings saved by the HA sidebar panel.
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
}
