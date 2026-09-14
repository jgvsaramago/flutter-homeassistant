/// One entry from Home Assistant's floor registry (`config/floor_registry/list`).
/// Drives the Climatização page's stat-tile grouping — one temp/humidity
/// tile pair per floor that has at least one area contributing data,
/// labelled with the floor's own name and ordered by [level] (HA's own
/// "how high up" ordering, e.g. -1 basement, 0 ground floor, 1 first floor).
class HaFloor {
  const HaFloor({required this.floorId, required this.name, this.level});

  final String floorId;
  final String name;
  final int? level;

  factory HaFloor.fromJson(Map<String, dynamic> json) => HaFloor(
    floorId: json['floor_id'] as String,
    name: json['name'] as String? ?? json['floor_id'] as String,
    level: (json['level'] as num?)?.toInt(),
  );
}
