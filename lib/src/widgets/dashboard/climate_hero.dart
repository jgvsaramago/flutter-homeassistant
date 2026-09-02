import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../sheets/dashboard/temperature_sheet.dart';
import '../../theme/nocturne_theme.dart';

String _formatTemp(HaEntity? entity) {
  if (entity == null || entity.isUnavailable) return '--';
  final value = double.tryParse(entity.state);
  return value == null ? entity.state : value.toStringAsFixed(1);
}

const _outdoorTempEntityId = 'sensor.sotao_gw2000a_wifiee57_outdoor_temperature';
const _floor0TempEntityId = 'sensor.temperatura_media_casa_piso_0';

// CO₂ health thresholds — same bands `TemperatureSheet`'s own CO₂ metric
// uses, kept local here since this card only needs the phrase, not the
// full metric-band machinery.
const _co2GoodBelow = 800;
const _co2ModerateUpTo = 1200;

// No CO₂/humidity sensor wired in this app yet — same static placeholder
// the design reference itself leaves untemplated.
const _co2Ppm = 612;

String _airQualityPhrase(int ppm) {
  if (ppm < _co2GoodBelow) return 'Boa qualidade';
  if (ppm <= _co2ModerateUpTo) return 'Qualidade moderada';
  return 'Qualidade crítica';
}

/// The badge counts [ClimateHero] renders, nothing else — a Dart record, so
/// Riverpod's `select` can compare it structurally and only notify the card
/// when one of these actually changes, instead of on every entity update
/// anywhere in the (potentially thousands-strong) HA instance.
typedef _StatusSummary = ({int lightsOn, int windowsOpen, bool hasGate, bool gateOpen});

_StatusSummary _summarizeStatus(Map<String, HaEntity> entities) {
  final values = entities.values;

  final lightsOn = values.where((e) => e.domain == 'light' && e.isOn).length;
  final windowsOpen = values.where((e) => e.domain == 'binary_sensor' && e.deviceClass == 'window' && e.isOn).length;

  final gates = values.where((e) => e.domain == 'cover' && e.deviceClass == 'garage');
  final gateOpen = gates.any((e) => e.state == 'open');
  final hasGate = gates.isNotEmpty;

  return (lightsOn: lightsOn, windowsOpen: windowsOpen, hasGate: hasGate, gateOpen: gateOpen);
}

/// Section 2 of the Homepage: the climate hero — a full-width gradient card
/// merging what used to be a separate status-badge row and an indoor/
/// outdoor climate card. Tapping it opens the same climate detail sheet the
/// old climate card opened. Home-mode selection (Normal/Ausente/Dormir/
/// Trabalho) had no backing HA entity even before this redesign — it was
/// local-only UI state controlling nothing — so it's now a static "Normal"
/// pill matching the design reference, rather than a real picker.
class ClimateHero extends ConsumerWidget {
  const ClimateHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temps = ref.watch(
      entitiesProvider.select((async) {
        final entities = async.value ?? const {};
        return (interior: entities[_floor0TempEntityId], exterior: entities[_outdoorTempEntityId]);
      }),
    );
    final status = ref.watch(entitiesProvider.select((async) => _summarizeStatus(async.value ?? const {})));

    return SizedBox(
      height: 244,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: NocturneColors.heroShadowColor, blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showTemperatureSheet(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.42, -0.91),
                    end: const Alignment(0.42, 0.91),
                    colors: [NocturneColors.heroGradientStart, NocturneColors.heroGradientEnd],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(top: 0, left: 0, right: 0, child: Container(height: 1, color: NocturneColors.heroInsetHighlight)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'INTERIOR',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                              const Spacer(),
                              _AirQualityChip(label: _airQualityPhrase(_co2Ppm)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${_formatTemp(temps.interior)}°',
                                style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -3, height: 0.9),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Exterior ${_formatTemp(temps.exterior)}°',
                                softWrap: false,
                                style: TextStyle(fontSize: 17, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const _ModePill(),
                              _StatusPill(label: '${status.lightsOn} luz${status.lightsOn == 1 ? '' : 'es'}'),
                              _StatusPill(label: '${status.windowsOpen} janela${status.windowsOpen == 1 ? '' : 's'}'),
                              if (status.hasGate) _StatusPill(label: status.gateOpen ? 'Portão aberto' : 'Portão fechado'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AirQualityChip extends StatelessWidget {
  const _AirQualityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(NocturneRadii.pill)),
      child: Text(label, softWrap: false, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }
}

/// Fixed colours regardless of theme — this pill's surface is opaque white
/// in both the light and dark hero, so it must never pick up a theme token.
class _ModePill extends StatelessWidget {
  const _ModePill();

  static const _iconColor = Color(0xFF6355BD);
  static const _labelColor = Color(0xFF191A20);
  static const _chevronColor = Color(0xFF767881);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(NocturneRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_outlined, size: 16, color: _iconColor),
          const SizedBox(width: 7),
          const Text('Normal', softWrap: false, style: TextStyle(color: _labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 14, color: _chevronColor),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(NocturneRadii.pill)),
      child: Text(label, softWrap: false, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}
