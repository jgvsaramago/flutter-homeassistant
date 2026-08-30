import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/energy_forecast_provider.dart';
import '../../../theme/nocturne_theme.dart';
import '../../../utils/pt_format.dart';

IconData _iconFor(SolarCondition c) => switch (c) {
  SolarCondition.sun => Icons.wb_sunny_outlined,
  SolarCondition.partly => Icons.wb_cloudy_outlined,
  SolarCondition.rain => Icons.umbrella_outlined,
};

Color _iconColorFor(SolarCondition c, bool isToday) => switch (c) {
  SolarCondition.sun => isToday ? NocturneColors.solarMark : NocturneColors.neutral400,
  SolarCondition.partly => NocturneColors.neutral400,
  SolarCondition.rain => NocturneColors.gridMark,
};

/// Section 8 of the Energia page: 7-day solar forecast, one row per
/// configured Solcast (or similar) day entity — see `energyForecastProvider`
/// for how each row's bar length, label colour and total are derived.
class EnergyForecast7dSection extends ConsumerWidget {
  const EnergyForecast7dSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(energyForecastProvider);
    final barMax = forecast.days.fold<double>(0, (m, d) => (d.kwh ?? 0) > m ? d.kwh! : m).clamp(1.0, double.infinity) * 1.15;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(NocturneRadii.primaryCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('PREVISÃO SOLAR · 7 DIAS', style: NocturneText.cardKicker)),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: NocturneColors.neutral400, decoration: TextDecoration.none),
                  children: [
                    const TextSpan(text: 'Total previsto '),
                    TextSpan(
                      text: formatKwh(forecast.sevenDayTotalKwh) ?? '--',
                      style: const TextStyle(color: NocturneColors.text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Column(
            children: [
              for (var i = 0; i < forecast.days.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _DayRow(day: forecast.days[i], isToday: i == 0, barMax: barMax),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.isToday, required this.barMax});

  final ForecastDay day;
  final bool isToday;
  final double barMax;

  @override
  Widget build(BuildContext context) {
    final labelColor = isToday ? NocturneColors.solarMark : NocturneColors.neutral300;
    final weight = isToday ? FontWeight.w600 : FontWeight.w500;
    final barColor = isToday ? NocturneColors.solarMark : Color.alphaBlend(NocturneColors.solarMark.withValues(alpha: 0.55), NocturneColors.neutral800);
    final fraction = day.kwh == null ? 0.0 : (day.kwh! / barMax).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(width: 58, child: Text(day.label, style: TextStyle(fontSize: 16, fontWeight: weight, color: labelColor, decoration: TextDecoration.none))),
        Icon(_iconFor(day.condition), size: 21, color: _iconColorFor(day.condition, isToday)),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(color: NocturneColors.neutral900, borderRadius: BorderRadius.circular(NocturneRadii.pill)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(NocturneRadii.pill))),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 86,
          child: Text(
            formatKwh(day.kwh) ?? '--',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 16, fontWeight: weight, color: isToday ? NocturneColors.text : NocturneColors.neutral300, decoration: TextDecoration.none),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            day.tempMax == null ? '--' : '${day.tempMax}°',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: NocturneColors.neutral500, decoration: TextDecoration.none),
          ),
        ),
      ],
    );
  }
}
