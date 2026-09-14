import '../../models/ha_entity.dart';
import '../../providers/rooms_provider.dart';

/// One floor's average temperature/humidity for the Climatização page's
/// stat tile row, sourced from each area's own temperature/humidity sensor
/// (`HaArea.temperatureEntityId`/`humidityEntityId`, set in HA's own Areas
/// & Zones settings) rather than anything configured a second time in this
/// app.
class FloorStat {
  const FloorStat({required this.label, required this.avgTemp, required this.avgHumidity});

  final String label;
  final double? avgTemp;
  final double? avgHumidity;
}

/// Only these two floors get a stat tile pair, in this fixed order —
/// matched against [HaFloor.name] case-insensitively. A household's HA
/// instance may have other floors (a garage, an exterior zone, ...) that
/// have no business on this page; unlike an area (which only shows up here
/// at all once the user wires an entity to it in Divisões), a floor has no
/// per-app opt-in, so this page picks the two it actually wants rather
/// than showing one tile pair per floor HA happens to have.
const _visibleFloorLabels = ['Piso 0', 'Sótão'];

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

/// Always returns exactly one [FloorStat] per [_visibleFloorLabels] entry,
/// in that order — "--"/"--" for one with no matching HA floor or no rooms
/// on it, same as the original fixed-tile design showed when unconfigured,
/// rather than the tile disappearing.
List<FloorStat> computeFloorStats(List<RoomEntry> rooms, Map<String, HaEntity> entities) {
  final roomsByLowerLabel = <String, List<RoomEntry>>{for (final label in _visibleFloorLabels) label.toLowerCase(): []};

  for (final room in rooms) {
    final floorName = room.floor?.name.trim().toLowerCase();
    final bucket = floorName == null ? null : roomsByLowerLabel[floorName];
    bucket?.add(room);
  }

  return [
    for (final label in _visibleFloorLabels)
      FloorStat(
        label: label,
        avgTemp: _average(roomsByLowerLabel[label.toLowerCase()]!.map((r) => _numeric(entities, r.area.temperatureEntityId)).whereType<double>()),
        avgHumidity: _average(roomsByLowerLabel[label.toLowerCase()]!.map((r) => _numeric(entities, r.area.humidityEntityId)).whereType<double>()),
      ),
  ];
}

/// pt-PT decimal-comma degree string, e.g. "21,5°" — `"--°"` when there's
/// nothing to average.
String formatDegreeComma(double? value) => value == null ? '--°' : '${value.toStringAsFixed(1).replaceAll('.', ',')}°';

/// Rounded percentage string, e.g. "47%" — `"--%"` when unset.
String formatPercent(double? value) => value == null ? '--%' : '${value.round()}%';
