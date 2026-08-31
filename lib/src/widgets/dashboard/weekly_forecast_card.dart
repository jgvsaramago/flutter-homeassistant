import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

enum _Sky { sunny, partlyCloudy, cloudy, rainy }

class _Day {
  const _Day(this.label, this.sky, this.high, this.low);
  final String label;
  final _Sky sky;
  final int high;
  final int low;
}

/// Section 5 of the Homepage: 7-day forecast. This app has no weather
/// integration yet, so — like the design reference, which has no `{{ }}`
/// bindings in this section — it's static placeholder data.
const _week = [
  _Day('Hoje', _Sky.sunny, 24, 16),
  _Day('Sex', _Sky.partlyCloudy, 22, 15),
  _Day('Sáb', _Sky.cloudy, 19, 13),
  _Day('Dom', _Sky.rainy, 17, 12),
  _Day('Seg', _Sky.sunny, 23, 14),
  _Day('Ter', _Sky.partlyCloudy, 21, 13),
  _Day('Qua', _Sky.cloudy, 18, 12),
];

IconData _iconFor(_Sky sky) => switch (sky) {
  _Sky.sunny => Icons.wb_sunny_outlined,
  _Sky.partlyCloudy => Icons.wb_cloudy_outlined,
  _Sky.cloudy => Icons.cloud_outlined,
  _Sky.rainy => Icons.umbrella_outlined,
};

Color _colorFor(_Sky sky) => switch (sky) {
  _Sky.sunny || _Sky.partlyCloudy => NocturneColors.amber,
  _Sky.cloudy || _Sky.rainy => NocturneColors.neutral500,
};

class WeeklyForecastCard extends StatelessWidget {
  const WeeklyForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: Card(
        child: Padding(
          padding: NocturneSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREVISÃO DE 7 DIAS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.3, color: NocturneColors.accent),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [for (final day in _week) Expanded(child: _DayColumn(day: day))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});

  final _Day day;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(day.label, style: TextStyle(fontSize: 18, color: NocturneColors.neutral300)),
        const SizedBox(height: 6),
        Icon(_iconFor(day.sky), size: 30, color: _colorFor(day.sky)),
        const SizedBox(height: 6),
        Text('${day.high}°', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        Text('${day.low}°', style: TextStyle(fontSize: 16, color: NocturneColors.neutral600)),
      ],
    );
  }
}
