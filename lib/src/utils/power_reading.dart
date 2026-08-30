import '../models/ha_entity.dart';

/// Reads a configured power sensor as kW, auto-detecting W vs kW from the
/// entity's own `unit_of_measurement` rather than assuming — a sensor
/// configured with the wrong assumed unit would otherwise be silently wrong
/// by 1000x. Readings within [zeroThresholdW] of zero snap to exactly 0.
/// Same convention `EnergyFlowCard` reads its own nodes with, duplicated
/// here (not imported from there) since that file's version is private and
/// this app deliberately leaves a stable, already-shipped widget alone
/// rather than reaching into it for a new feature.
double? readPowerKw(Map<String, HaEntity> entities, String? entityId, double zeroThresholdW) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  final raw = double.tryParse(entity.state);
  if (raw == null) return null;
  final kw = entity.unitOfMeasurement?.toLowerCase() == 'kw' ? raw : raw / 1000;
  return kw.abs() * 1000 < zeroThresholdW ? 0.0 : kw;
}
