import '../../models/ha_entity.dart';
import '../../providers/rooms_provider.dart';

/// One floor's average temperature/humidity for the Climatização page's
/// stat tile row — one pair of tiles per floor that has at least one area
/// contributing a reading, sourced from each area's own temperature/
/// humidity sensor (`HaArea.temperatureEntityId`/`humidityEntityId`, set in
/// HA's own Areas & Zones settings) rather than anything configured a
/// second time in this app.
class FloorStat {
  const FloorStat({required this.label, required this.avgTemp, required this.avgHumidity});

  /// The floor's own name from HA, or "Sem piso" for areas with no floor
  /// assigned — grouped together so they still show up rather than being
  /// silently dropped from the page entirely.
  final String label;
  final double? avgTemp;
  final double? avgHumidity;
}

double? _numeric(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

double? _average(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

const _noFloorLabel = 'Sem piso';

/// Groups [rooms] by [RoomEntry.floor] (level order, then name; areas with
/// no floor last) and averages each group's area temperature/humidity
/// sensors. A floor with zero rooms actually reporting a numeric value
/// still gets a tile (both "--"), same as the original design's fixed
/// Piso 0/Sótão tiles did when unconfigured — only a floor with *no rooms
/// at all* is omitted.
List<FloorStat> computeFloorStats(List<RoomEntry> rooms, Map<String, HaEntity> entities) {
  final byFloorKey = <String, List<RoomEntry>>{};
  final labelByKey = <String, String>{};
  final levelByKey = <String, int>{};

  for (final room in rooms) {
    final floor = room.floor;
    final key = floor?.floorId ?? '';
    byFloorKey.putIfAbsent(key, () => []).add(room);
    labelByKey[key] = floor?.name ?? _noFloorLabel;
    levelByKey[key] = floor?.level ?? (1 << 30);
  }

  final keys = byFloorKey.keys.toList()
    ..sort((a, b) {
      final byLevel = levelByKey[a]!.compareTo(levelByKey[b]!);
      return byLevel != 0 ? byLevel : labelByKey[a]!.compareTo(labelByKey[b]!);
    });

  return [
    for (final key in keys)
      FloorStat(
        label: labelByKey[key]!,
        avgTemp: _average(byFloorKey[key]!.map((r) => _numeric(entities, r.area.temperatureEntityId)).whereType<double>()),
        avgHumidity: _average(byFloorKey[key]!.map((r) => _numeric(entities, r.area.humidityEntityId)).whereType<double>()),
      ),
  ];
}

/// pt-PT decimal-comma degree string, e.g. "21,5°" — `"--°"` when there's
/// nothing to average.
String formatDegreeComma(double? value) => value == null ? '--°' : '${value.toStringAsFixed(1).replaceAll('.', ',')}°';

/// Rounded percentage string, e.g. "47%" — `"--%"` when unset.
String formatPercent(double? value) => value == null ? '--%' : '${value.round()}%';
