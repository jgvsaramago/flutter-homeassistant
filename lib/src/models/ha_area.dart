/// One entry from Home Assistant's area registry (`config/area_registry/list`).
/// Areas are the source of truth for the Divisões room list — see
/// `RoomConfig` — rather than a free-typed name, so a divisão always
/// corresponds to a real HA area and can resolve its floor/temperature/
/// humidity from it instead of those being configured a second time in
/// this app.
class HaArea {
  const HaArea({required this.areaId, required this.name, this.floorId, this.temperatureEntityId, this.humidityEntityId});

  final String areaId;
  final String name;

  /// Which `HaFloor` this area belongs to, if any — an area with no floor
  /// assigned in HA has this unset.
  final String? floorId;

  /// The area's own `sensor.*` picks (HA's "Areas & Zones" settings —
  /// Sensors section), if the household has set them there. Feeds the
  /// Climatização page's per-floor stat tiles and the Divisões room card's
  /// hero temperature — neither is configured again in this app.
  final String? temperatureEntityId;
  final String? humidityEntityId;

  factory HaArea.fromJson(Map<String, dynamic> json) => HaArea(
    areaId: json['area_id'] as String,
    name: json['name'] as String? ?? json['area_id'] as String,
    floorId: json['floor_id'] as String?,
    temperatureEntityId: json['temperature_entity_id'] as String?,
    humidityEntityId: json['humidity_entity_id'] as String?,
  );
}
