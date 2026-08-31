import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../theme/nocturne_theme.dart';
import '../../sheets/dashboard/temperature_sheet.dart';

String _formatTemp(HaEntity? entity) {
  if (entity == null || entity.isUnavailable) return '--';
  final value = double.tryParse(entity.state);
  return value == null ? entity.state : value.toStringAsFixed(1);
}

const _outdoorTempEntityId = 'sensor.sotao_gw2000a_wifiee57_outdoor_temperature';
const _floor0TempEntityId = 'sensor.temperatura_media_casa_piso_0';

enum _HomeMode { normal, away, sleep, work }

class _ModeSpec {
  const _ModeSpec(this.label, this.icon, this.hue);
  final String label;
  final IconData icon;
  final Color hue;
}

final _modeSpecs = {
  _HomeMode.normal: _ModeSpec('Normal', Icons.home_outlined, NocturneColors.accent),
  _HomeMode.away: _ModeSpec('Ausente', Icons.logout, NocturneColors.amber),
  _HomeMode.sleep: _ModeSpec('Dormir', Icons.bedtime_outlined, NocturneColors.blue),
  _HomeMode.work: _ModeSpec('Trabalho', Icons.work_outline, NocturneColors.green),
};

/// Section 3 of the Homepage: indoor/outdoor temperature card + home-mode
/// selector card, side by side.
///
/// Temperatures are live sensor readings (same entity ids the app already
/// keys off of elsewhere); humidity and the outdoor blurb have no sensor
/// counterpart in this app yet, so — like the design reference itself, which
/// only templated the temperature values and left these as static copy —
/// they're static placeholders. The mode selector has no backing HA entity
/// (this household has no `input_select` for it), so it's local UI state.
class ClimateModeRow extends StatefulWidget {
  const ClimateModeRow({super.key});

  @override
  State<ClimateModeRow> createState() => _ClimateModeRowState();
}

class _ClimateModeRowState extends State<ClimateModeRow> {
  _HomeMode _mode = _HomeMode.normal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 333, child: _ClimateCard()),
          const SizedBox(width: 16),
          Expanded(
            child: _ModeCard(selected: _mode, onSelect: (mode) => setState(() => _mode = mode)),
          ),
        ],
      ),
    );
  }
}

// CO₂ health thresholds — kept in one place so the same rule could drive an
// air-quality label elsewhere later, not just this pill.
const _co2GoodBelow = 800;
const _co2ModerateUpTo = 1200;

class _Co2Style {
  const _Co2Style(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

_Co2Style _co2Style(int ppm) {
  final Color hue;
  final double mix;
  if (ppm < _co2GoodBelow) {
    hue = NocturneColors.green;
    mix = 0.16;
  } else if (ppm <= _co2ModerateUpTo) {
    hue = NocturneColors.amber;
    mix = 0.16;
  } else {
    hue = NocturneColors.red;
    mix = 0.20;
  }
  return _Co2Style(Color.alphaBlend(hue.withValues(alpha: mix), NocturneColors.surface), hue);
}

class _ClimateCard extends ConsumerWidget {
  const _ClimateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selecting just these two entities (not the whole map) means this card
    // only rebuilds when one of them actually changes, not on every other
    // entity update flushed from `entitiesProvider` — unrelated entities
    // keep the same object identity across a flush, so `select`'s equality
    // check correctly skips a rebuild for anything but these two ids.
    final temps = ref.watch(
      entitiesProvider.select((async) {
        final entities = async.value ?? const {};
        return (interior: entities[_floor0TempEntityId], exterior: entities[_outdoorTempEntityId]);
      }),
    );
    final interior = temps.interior;
    final exterior = temps.exterior;
    // No humidity/CO₂ sensors wired in this app yet — static placeholders,
    // same treatment as the design reference's own non-templated copy here.
    const humidityPercent = 47;
    const co2Ppm = 612;
    final co2Style = _co2Style(co2Ppm);

    return Card(
      child: InkWell(
        onTap: () => showTemperatureSheet(context),
        borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
        child: Padding(
          padding: NocturneSpacing.cardPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'INTERIOR',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: NocturneColors.accent),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatTemp(interior),
                            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w600, height: 0.95, letterSpacing: -2),
                          ),
                          const SizedBox(width: 4),
                          Text('°C', style: TextStyle(fontSize: 21, color: NocturneColors.neutral500)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Pill(
                        icon: Icons.water_drop,
                        background: Color.alphaBlend(NocturneColors.blue.withValues(alpha: 0.16), NocturneColors.surface),
                        foreground: NocturneColors.blue,
                        label: '$humidityPercent%',
                      ),
                      const SizedBox(height: 8),
                      _Pill(icon: Icons.co2, background: co2Style.background, foreground: co2Style.foreground, label: '$co2Ppm ppm'),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: NocturneColors.divider))),
                child: Row(
                  children: [
                    Icon(Icons.wb_cloudy_outlined, size: 19, color: NocturneColors.neutral500),
                    const SizedBox(width: 12),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 16, color: NocturneColors.neutral300),
                        children: [
                          const TextSpan(text: 'Exterior '),
                          TextSpan(
                            text: '${_formatTemp(exterior)}°C',
                            style: TextStyle(fontWeight: FontWeight.w600, color: NocturneColors.text),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('Chuva fraca', style: TextStyle(fontSize: 16, color: NocturneColors.neutral500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.background, required this.foreground, required this.label});

  final IconData icon;
  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(NocturneRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 7),
          Text(label, softWrap: false, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: foreground)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.selected, required this.onSelect});

  final _HomeMode selected;
  final ValueChanged<_HomeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: NocturneSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MODO',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.3, color: NocturneColors.accent),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: [for (final mode in _HomeMode.values) _ModeButton(mode: mode, active: mode == selected, onSelect: onSelect)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.active, required this.onSelect});

  final _HomeMode mode;
  final bool active;
  final ValueChanged<_HomeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final spec = _modeSpecs[mode]!;
    final color = active ? spec.hue : Color.lerp(spec.hue, NocturneColors.neutral600, 0.45)!;

    return Material(
      color: active ? spec.hue.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(NocturneRadii.chip),
      child: InkWell(
        onTap: () => onSelect(mode),
        borderRadius: BorderRadius.circular(NocturneRadii.chip),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NocturneRadii.chip),
            border: active ? null : Border.all(color: spec.hue.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(spec.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                spec.label,
                style: TextStyle(fontSize: 15, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
