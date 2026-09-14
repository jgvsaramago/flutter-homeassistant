import '../../models/ha_entity.dart';
import '../../providers/rooms_store.dart';

/// Piso 0 / Sótão average temperature and humidity for the Climatização
/// page's stat tile row — mirrors the reference design's `zoneAvg()`, but
/// sourced from whichever rooms the household has actually tagged with
/// [RoomConfig.climateZone] instead of a hardcoded room-name list.
class ClimateZoneStats {
  const ClimateZoneStats({required this.floor0Temp, required this.floor0Humidity, required this.atticTemp, required this.atticHumidity});

  final double? floor0Temp;
  final double? floor0Humidity;
  final double? atticTemp;
  final double? atticHumidity;
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

String _zoneOf(RoomConfig room) => room.climateZone ?? RoomClimateZone.floor0;

ClimateZoneStats computeClimateZoneStats(List<RoomConfig> rooms, Map<String, HaEntity> entities) {
  final floor0 = rooms.where((r) => _zoneOf(r) == RoomClimateZone.floor0);
  final attic = rooms.where((r) => _zoneOf(r) == RoomClimateZone.attic);

  return ClimateZoneStats(
    floor0Temp: _average(floor0.map((r) => _numeric(entities, r.temperatureEntityId)).whereType<double>()),
    floor0Humidity: _average(floor0.map((r) => _numeric(entities, r.humidityEntityId)).whereType<double>()),
    atticTemp: _average(attic.map((r) => _numeric(entities, r.temperatureEntityId)).whereType<double>()),
    atticHumidity: _average(attic.map((r) => _numeric(entities, r.humidityEntityId)).whereType<double>()),
  );
}

/// pt-PT decimal-comma degree string, e.g. "21,5°" — `"--°"` when there's
/// nothing to average.
String formatDegreeComma(double? value) => value == null ? '--°' : '${value.toStringAsFixed(1).replaceAll('.', ',')}°';

/// Rounded percentage string, e.g. "47%" — `"--%"` when unset.
String formatPercent(double? value) => value == null ? '--%' : '${value.round()}%';
