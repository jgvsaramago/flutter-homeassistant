import '../ha_client/ha_websocket_client.dart';
import 'settings_json_utils.dart';

/// Which Climatização-page stat-tile zone a room's temperature/humidity
/// count toward. Stored as a plain string (rather than a Dart `enum`) so an
/// unrecognized/future value round-trips through settings JSON harmlessly
/// instead of throwing — same defensive convention `blankStringsToNull`'s
/// callers already rely on elsewhere.
abstract final class RoomClimateZone {
  /// Default — also what a null/unset value means, so every room already
  /// configured before this field existed keeps counting toward "Piso 0"
  /// exactly as it implicitly did.
  static const floor0 = 'floor0';
  static const attic = 'attic';

  /// Counts toward neither stat-tile average (e.g. a garage or a shared
  /// building area) — mirrors the reference design's own exclusion list.
  static const excluded = 'excluded';
}

/// One room card on the Divisões page — a household picks its own rooms and
/// wires each one to whatever real HA entities it has (all optional; an
/// unset field just means that room shows no reading/icon for it, same
/// convention as every other entity config in this app). No entity ids are
/// baked in by default: this app has no fixed idea of what rooms exist.
///
/// [climateEntityId] and [coverEntityId] double as the Climatização page's
/// own dynamic entity list: an AC unit card is rendered for every room with
/// a [climateEntityId], a shutter card for every room with a
/// [coverEntityId] — so adding/removing either on that page is just editing
/// the room list here, rather than a second parallel settings list.
class RoomConfig {
  const RoomConfig({
    required this.name,
    this.temperatureEntityId,
    this.humidityEntityId,
    this.secondaryEntityId,
    this.lightEntityId,
    this.windowEntityId,
    this.climateEntityId,
    this.speakerEntityId,
    this.coverEntityId,
    this.climateZone,
  });

  final String name;

  /// Room temperature — a `sensor.*` entity, shown as the card's hero number.
  final String? temperatureEntityId;

  /// Room humidity — a `sensor.*` entity (device class `humidity`). Only
  /// consumed by the Climatização page's floor/sótão humidity tiles; the
  /// Divisões room card itself still reads humidity out of
  /// [secondaryEntityId] like every other status-line source.
  final String? humidityEntityId;

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

  /// One of [RoomClimateZone]'s values; null means [RoomClimateZone.floor0].
  final String? climateZone;

  RoomConfig copyWith({
    String? name,
    String? temperatureEntityId,
    String? humidityEntityId,
    String? secondaryEntityId,
    String? lightEntityId,
    String? windowEntityId,
    String? climateEntityId,
    String? speakerEntityId,
    String? coverEntityId,
    String? climateZone,
  }) {
    return RoomConfig(
      name: name ?? this.name,
      temperatureEntityId: temperatureEntityId ?? this.temperatureEntityId,
      humidityEntityId: humidityEntityId ?? this.humidityEntityId,
      secondaryEntityId: secondaryEntityId ?? this.secondaryEntityId,
      lightEntityId: lightEntityId ?? this.lightEntityId,
      windowEntityId: windowEntityId ?? this.windowEntityId,
      climateEntityId: climateEntityId ?? this.climateEntityId,
      speakerEntityId: speakerEntityId ?? this.speakerEntityId,
      coverEntityId: coverEntityId ?? this.coverEntityId,
      climateZone: climateZone ?? this.climateZone,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'temperatureEntityId': temperatureEntityId,
    'humidityEntityId': humidityEntityId,
    'secondaryEntityId': secondaryEntityId,
    'lightEntityId': lightEntityId,
    'windowEntityId': windowEntityId,
    'climateEntityId': climateEntityId,
    'speakerEntityId': speakerEntityId,
    'coverEntityId': coverEntityId,
    'climateZone': climateZone,
  };

  factory RoomConfig.fromJson(Map<String, dynamic> json) => RoomConfig(
    name: json['name'] as String? ?? '',
    temperatureEntityId: json['temperatureEntityId'] as String?,
    humidityEntityId: json['humidityEntityId'] as String?,
    secondaryEntityId: json['secondaryEntityId'] as String?,
    lightEntityId: json['lightEntityId'] as String?,
    windowEntityId: json['windowEntityId'] as String?,
    climateEntityId: json['climateEntityId'] as String?,
    speakerEntityId: json['speakerEntityId'] as String?,
    coverEntityId: json['coverEntityId'] as String?,
    climateZone: json['climateZone'] as String?,
  );
}

/// Persists the Divisões room list via the `flutter_homeassistant` HA
/// integration, so any device running this app shares the same room list.
/// Unlike the energy card's 4 device slots, rooms have no fixed physical
/// layout to cap against, so the list is uncapped.
class RoomsStore {
  RoomsStore(this._client);

  final HaWebSocketClient _client;

  static const _key = 'rooms';

  Future<List<RoomConfig>> read() async {
    final raw = await _client.getSettings(_key);
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>().map(RoomConfig.fromJson).toList();
  }

  Future<void> save(List<RoomConfig> rooms) async {
    final valid = rooms.where((r) => r.name.trim().isNotEmpty).toList();
    await _client.setSettings(_key, blankStringsToNull(valid.map((r) => r.toJson()).toList()));
  }
}
