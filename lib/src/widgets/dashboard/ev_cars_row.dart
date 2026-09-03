import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ev_cars_provider.dart';
import '../../providers/ev_cars_store.dart';
import '../../providers/ha_providers.dart';
import '../../sheets/dashboard/ev_sheet.dart';
import '../../theme/nocturne_theme.dart';

double? _readPercent(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

/// Range, formatted with whatever unit the sensor itself reports (this app
/// does no km/mi conversion, same as every other distance reading in the
/// dashboard) — `"--"` when unconfigured, unavailable, or non-numeric.
String _formatRange(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return '--';
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return '--';
  final value = double.tryParse(entity.state);
  if (value == null) return '--';
  return '${value.round()} ${entity.unitOfMeasurement ?? 'km'}';
}

/// States (exact match, not substring — "Disconnected" must not match just
/// because it contains "connect") this app treats as "on" for a charging or
/// plug-connected entity, covering both a plain `binary_sensor` and the text
/// states some EV integrations report instead.
const _truthyStates = {
  'on',
  'true',
  '1',
  'yes',
  'charging',
  'connected',
  'plugged_in',
  'plugged',
};

/// Null means "not configured/unavailable", distinct from a configured
/// sensor that's simply reporting off/false.
bool? _readBoolState(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return _truthyStates.contains(entity.state.toLowerCase());
}

/// Charging takes priority over "just plugged in" (a full battery stays
/// plugged in without drawing current); "--" only when neither entity this
/// depends on is configured at all.
String _statusText(bool? charging, bool? plugged) {
  if (charging == null && plugged == null) return '--';
  if (charging == true) return 'A carregar';
  if (plugged == true) return 'Ligado, sem carregar';
  return 'Sem carregamento';
}

/// SoC bar fill: green while charging, blue while just plugged in (cable
/// connected but not drawing current — a full battery stays plugged in
/// without charging, so this is worth distinguishing from truly idle),
/// neutral otherwise.
Color _socBarColor(bool? charging, bool? plugged) {
  if (charging == true) return NocturneColors.green;
  if (plugged == true) return NocturneColors.blue;
  return NocturneColors.neutral500;
}

/// `null`/blank means "no photo configured", distinct from a URL that's
/// merely unreachable (which `Image.network`'s own `errorBuilder` handles).
String? _normalizedUrl(String? url) =>
    (url == null || url.trim().isEmpty) ? null : url.trim();

/// The already-derived values one [_EvCard] renders, nothing else — a Dart
/// record, so `entitiesProvider.select` can compare it structurally and only
/// notify this side of the row when its own reading actually changes,
/// instead of on every entity update anywhere in the HA instance.
typedef _CarReadout = ({double? batteryPct, bool? charging, bool? plugged, String range});

_CarReadout _readCar(Map<String, HaEntity> entities, EvCarConfig car) {
  return (
    batteryPct: _readPercent(entities, car.batterySocEntityId),
    charging: _readBoolState(entities, car.chargingEntityId),
    plugged: _readBoolState(entities, car.plugConnectedEntityId),
    range: _formatRange(entities, car.rangeEntityId),
  );
}

/// Section 4 of the Homepage: two EV cards, left and right, each reading its
/// own name and live battery/range/charging/plug state from Settings →
/// Homepage → Carros elétricos-configured HA entities. An unconfigured or
/// unavailable field shows "--", same convention as the energy-flow card's
/// own nodes.
class EvCarsRow extends ConsumerWidget {
  const EvCarsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(evCarsConfigProvider);
    // Selecting the derived readout (not the raw entity map) means each
    // card only rebuilds when its own car's battery/charging/plug/range
    // actually changes, not on every unrelated entity update flushed from
    // `entitiesProvider`.
    final left = ref.watch(entitiesProvider.select((async) => _readCar(async.value ?? const {}, config.left)));
    final right = ref.watch(entitiesProvider.select((async) => _readCar(async.value ?? const {}, config.right)));

    return SizedBox(
      height: 256,
      child: Row(
        children: [
          Expanded(
            child: _EvCard(
              side: CarSide.left,
              car: config.left,
              readout: left,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _EvCard(
              side: CarSide.right,
              car: config.right,
              readout: right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvCard extends StatelessWidget {
  const _EvCard({
    required this.side,
    required this.car,
    required this.readout,
  });

  final CarSide side;
  final EvCarConfig car;
  final _CarReadout readout;

  @override
  Widget build(BuildContext context) {
    final batteryPct = readout.batteryPct;
    final charging = readout.charging;
    final plugged = readout.plugged;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showEvSheet(context, side),
        child: Padding(
          padding: NocturneSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (charging == true) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.bolt,
                      size: 16,
                      color: NocturneColors.amber,
                    ),
                  ] else if (plugged == true) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.electrical_services,
                      size: 16,
                      color: NocturneColors.neutral400,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: FractionallySizedBox(
                      widthFactor: 0.74,
                      child: SizedBox(
                        height: 74,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            NocturneRadii.chip,
                          ),
                          child: _CarPhoto(url: _normalizedUrl(car.photoUrl)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    batteryPct == null ? '--' : '${batteryPct.round()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    readout.range,
                    style: TextStyle(
                      fontSize: 15,
                      color: NocturneColors.neutral500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(NocturneRadii.pill),
                child: LinearProgressIndicator(
                  value: (batteryPct ?? 0) / 100,
                  minHeight: 7,
                  backgroundColor: NocturneColors.neutral800,
                  valueColor: AlwaysStoppedAnimation(_socBarColor(charging, plugged)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusText(charging, plugged),
                style: TextStyle(
                  fontSize: 14,
                  color: NocturneColors.neutral500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home card's 90%×88 photo slot: the configured [url] if it loads,
/// else the neutral gradient placeholder with a car glyph — same fallback
/// shape as `_ArtworkPlaceholder` in `music_sheet.dart`.
class _CarPhoto extends ConsumerWidget {
  const _CarPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = this.url;
    if (url == null) return const _CarPhotoPlaceholder();
    final connectionConfig = ref.watch(connectionConfigProvider);
    return Image.network(
      url,
      fit: BoxFit.cover,
      headers: haImageAuthHeaders(connectionConfig, url),
      errorBuilder: (context, error, stackTrace) =>
          const _CarPhotoPlaceholder(),
    );
  }
}

class _CarPhotoPlaceholder extends StatelessWidget {
  const _CarPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NocturneColors.neutral800, NocturneColors.neutral900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_outlined,
          color: NocturneColors.neutral600,
          size: 28,
        ),
      ),
    );
  }
}
