import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/energy_history_provider.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/pt_format.dart';

const _pxPerKwh = 52.0;
const _areaHeight = 130.0;

/// Section 6 of the Energia page: one column per hour, consumption stacked
/// by source above the zero line and battery-charge energy below it, same
/// vertical scale in both directions — modelled on Home Assistant's own
/// "Eletricidade" energy graph. Every bar comes from `EnergyHistoryData`
/// (HA recorder history for today, integrated into hourly kWh), not typed
/// numbers.
class EnergyConsumptionChart extends ConsumerWidget {
  const EnergyConsumptionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(energyHistoryProvider).value ?? EnergyHistoryData.empty;
    final hours = history.hours.isEmpty ? List.generate(24, (h) => EnergyHourlyBucket.zero(h)) : history.hours;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('CONSUMO POR HORA · POR FONTE', style: NocturneText.cardKicker)),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none),
                  children: [
                    const TextSpan(text: 'Casa '),
                    TextSpan(
                      text: formatKwh(history.hasHome ? history.consumedTodayKwh : null) ?? '--',
                      style: TextStyle(color: NocturneColors.text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            // Two 130px areas + the 10px tariff-mark gutter between them +
            // the 20px hour-label row every column adds below that — the
            // axis column itself only needs the first 270px (see
            // `_AxisLabels`), but the Row's tallest child (an `_HourColumn`)
            // needs the full 290px or its fixed-height children overflow.
            height: _areaHeight * 2 + 10 + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 52, child: _AxisLabels()),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final h in hours) Expanded(child: _HourColumn(bucket: h, isNow: h.hour == now.hour))],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

/// Ticks land on the chart's real geometry — 0 / 65 / 130 / 205 / 270 px —
/// laid out with `Positioned`, never `MainAxisAlignment.spaceBetween`
/// (which would put the "0" tick at the row's middle only by coincidence,
/// and drift if the tariff-mark gutter between the two areas ever changes).
class _AxisLabels extends StatelessWidget {
  const _AxisLabels();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: NocturneColors.neutral600, decoration: TextDecoration.none);
    final zeroStyle = TextStyle(fontSize: 13, color: NocturneColors.neutral500, decoration: TextDecoration.none);
    Widget tick(double top, String text, TextStyle textStyle) {
      return Positioned(right: 0, top: top, child: FractionalTranslation(translation: const Offset(0, -0.5), child: Text(text, style: textStyle)));
    }

    return SizedBox(
      height: _areaHeight * 2 + 10,
      // Every label is vertically centred on its tick line via a -50%
      // translation (matching the CSS reference's own
      // `transform: translateY(-50%)`), so the top and bottom ticks each
      // overflow the stack's own bounds by half a line — Stack clips that
      // away by default (`Clip.hardEdge`), unlike CSS's non-clipping
      // default, so it has to be turned off here.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          tick(0, '2,5 kWh', style),
          tick(65, '1,25', style),
          tick(_areaHeight, '0', zeroStyle),
          tick(_areaHeight * 2 - 65 + 10, '1,25', style),
          tick(_areaHeight * 2 + 10, '2,5', style),
        ],
      ),
    );
  }
}

class _HourColumn extends StatelessWidget {
  const _HourColumn({required this.bucket, required this.isNow});

  final EnergyHourlyBucket bucket;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final isVazio = bucket.hour <= 8 || bucket.hour >= 22;
    final tariffColor = isVazio ? NocturneColors.batteryMark : NocturneColors.gridMark;

    // Top-to-bottom: grid, battery, solar — solar sits at the bottom of the
    // stack (drawn last in a bottom-aligned column), matching the reference
    // template's own child order under `justify-content: flex-end`.
    final segments = [
      (bucket.gridToHouseKwh, NocturneColors.gridMark),
      (bucket.fromBatteryKwh, NocturneColors.batteryMark),
      (bucket.solarToHouseKwh, NocturneColors.solarMark),
    ];
    final firstNonZero = segments.indexWhere((s) => s.$1 > 0.001);

    return Opacity(
      opacity: bucket.isFuture ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          children: [
            SizedBox(
              height: _areaHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < segments.length; i++)
                    if (segments[i].$1 > 0.001)
                      Container(
                        height: (segments[i].$1 * _pxPerKwh).clamp(0, _areaHeight),
                        decoration: BoxDecoration(
                          color: segments[i].$2,
                          borderRadius: i == firstNonZero ? const BorderRadius.vertical(top: Radius.circular(5)) : null,
                        ),
                      ),
                ],
              ),
            ),
            Container(height: 4, margin: const EdgeInsets.symmetric(vertical: 3), decoration: BoxDecoration(color: tariffColor, borderRadius: BorderRadius.circular(2))),
            SizedBox(
              height: _areaHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: (bucket.toBatteryKwh * _pxPerKwh).clamp(0, _areaHeight),
                  decoration: BoxDecoration(color: NocturneColors.batteryMark, borderRadius: BorderRadius.vertical(bottom: Radius.circular(5))),
                ),
              ),
            ),
            SizedBox(
              height: 20,
              child: Center(
                child: Text(
                  bucket.hour.toString().padLeft(2, '0'),
                  style: TextStyle(fontSize: 12, color: isNow ? NocturneColors.accent300 : NocturneColors.neutral500, decoration: TextDecoration.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 62),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _LegendSwatch(color: NocturneColors.solarMark, label: 'Solar'),
              _LegendSwatch(color: NocturneColors.batteryMark, label: 'Bateria'),
              _LegendSwatch(color: NocturneColors.gridMark, label: 'Rede'),
            ],
          ),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _LegendMark(color: NocturneColors.batteryMark, label: 'Vazio'),
              _LegendMark(color: NocturneColors.gridMark, label: 'Fora de vazio'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
      ],
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: NocturneColors.neutral500, decoration: TextDecoration.none)),
      ],
    );
  }
}
