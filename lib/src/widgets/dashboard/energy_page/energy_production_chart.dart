import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/energy_forecast_provider.dart';
import '../../../providers/energy_history_provider.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/pt_format.dart';

const _plotHeight = 200.0;

double _ceilToNice(double value, double step) => value <= 0 ? step : (value / step).ceilToDouble() * step;

/// Section 7 of the Energia page: today's actual solar production per hour
/// (from HA history) with the Solcast "previsto" bars behind it, when
/// configured. Unlike the consumption chart's fixed 52px/kWh geometry (an
/// explicit design constant, not data-derived), this chart's Y axis is
/// computed from the real peak — a fixed literal here would either clip a
/// large system's real peak or leave a small one looking tiny, and this
/// codebase already has a precedent for scaling a real-data chart's axis to
/// its own data (`TemperatureSheetChart`'s `_floorTo`/`_ceilTo`).
class EnergyProductionChart extends ConsumerWidget {
  const EnergyProductionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(energyHistoryProvider).value ?? EnergyHistoryData.empty;
    final forecast = ref.watch(energyForecastProvider);
    final hours = history.hours.isEmpty ? List.generate(24, (h) => EnergyHourlyBucket.zero(h)) : history.hours;
    final expected = forecast.hourlyExpectedKwh;
    final now = DateTime.now();

    final actualPeak = hours.fold<double>(0, (m, h) => h.solarKwh > m ? h.solarKwh : m);
    final expectedPeak = expected.fold<double>(0, (m, v) => v > m ? v : m);
    final axisMax = _ceilToNice((actualPeak > expectedPeak ? actualPeak : expectedPeak) * 1.15, 0.5).clamp(0.5, double.infinity);

    double? peakKw = history.peakSolarKw;
    final peakTime = history.peakSolarTime;
    final peakText = peakKw == null || peakTime == null
        ? null
        : 'Pico ${formatKw(peakKw)} às ${peakTime.hour.toString().padLeft(2, '0')}:${peakTime.minute.toString().padLeft(2, '0')}';

    final expectedSoFar = forecast.hasHourlyForecast ? _sumUpToNow(expected, now) : null;
    final actualSoFar = history.hasSolar ? _sumUpToHour(hours, now.hour) : null;
    final deviationText = (expectedSoFar != null && expectedSoFar > 0.01 && actualSoFar != null)
        ? 'Desvio ${_signedPercent((actualSoFar - expectedSoFar) / expectedSoFar * 100)} vs previsto'
        : null;

    return Container(
      height: 400,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('PRODUÇÃO HOJE · HORA A HORA', style: NocturneText.cardKicker)),
              _LegendSwatch(color: NocturneColors.solarMark, label: 'Produzido'),
              const SizedBox(width: 18),
              _LegendSwatch(color: Color.alphaBlend(NocturneColors.solarMark.withValues(alpha: 0.26), NocturneColors.surface), label: 'Previsto'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 40, child: _YAxis(axisMax: axisMax)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var h = 0; h < 24; h++)
                              Expanded(
                                child: _Bar(
                                  actual: hours[h].isFuture ? null : hours[h].solarKwh,
                                  expected: forecast.hasHourlyForecast ? expected[h] : null,
                                  axisMax: axisMax,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 26,
                        child: Row(
                          children: [
                            for (var h = 0; h < 24; h++)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    h.toString().padLeft(2, '0'),
                                    style: TextStyle(fontSize: 12, color: h == now.hour ? NocturneColors.accent300 : NocturneColors.neutral500, decoration: TextDecoration.none),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
              children: [
                Text(peakText ?? '--', style: TextStyle(fontSize: 15, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
                const SizedBox(width: 26),
                Text(deviationText ?? '--', style: TextStyle(fontSize: 15, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _sumUpToHour(List<EnergyHourlyBucket> hours, int hour) {
    var total = 0.0;
    for (var h = 0; h <= hour && h < hours.length; h++) {
      total += hours[h].solarKwh;
    }
    return total;
  }

  double _sumUpToNow(List<double> hourly, DateTime now) {
    var total = 0.0;
    for (var h = 0; h < now.hour && h < hourly.length; h++) {
      total += hourly[h];
    }
    // Partial credit for the current, still-in-progress hour.
    if (now.hour < hourly.length) total += hourly[now.hour] * (now.minute / 60);
    return total;
  }

  String _signedPercent(double value) => '${value >= 0 ? '+' : ''}${value.round()}%';
}

class _YAxis extends StatelessWidget {
  const _YAxis({required this.axisMax});

  final double axisMax;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: NocturneColors.neutral600, decoration: TextDecoration.none);
    return SizedBox(
      height: _plotHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${ptNumber(axisMax, decimals: axisMax < 2 ? 1 : 0)} kW', style: style),
          for (var i = 3; i >= 1; i--) Text(ptNumber(axisMax * i / 4, decimals: axisMax < 2 ? 1 : 0), style: style),
          Text('0', style: style),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.actual, required this.expected, required this.axisMax});

  final double? actual;
  final double? expected;
  final double axisMax;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _plotHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (expected != null && expected! > 0)
              FractionallySizedBox(
                heightFactor: (expected! / axisMax).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(NocturneColors.solarMark.withValues(alpha: 0.26), NocturneColors.surface),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
              ),
            if (actual != null && actual! > 0)
              FractionallySizedBox(
                heightFactor: (actual! / axisMax).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(color: NocturneColors.solarMark, borderRadius: BorderRadius.vertical(top: Radius.circular(5))),
                ),
              ),
          ],
        ),
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
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 14, color: NocturneColors.neutral400, decoration: TextDecoration.none)),
      ],
    );
  }
}
