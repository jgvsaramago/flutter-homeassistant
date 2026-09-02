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

// Fixed hexes (not theme tokens) for the sun/rain strokes — the design
// reference uses the same literal values in both the light and dark
// theme; only the cloud stroke actually varies by theme.
const _sunStroke = Color(0xFFC8A05A);
const _rainStroke = Color(0xFF2F72B8);

Color _colorFor(_Sky sky) => switch (sky) {
  _Sky.sunny => _sunStroke,
  _Sky.partlyCloudy || _Sky.cloudy => NocturneColors.forecastCloudStroke,
  _Sky.rainy => _rainStroke,
};

/// Range-bar fill gradient, chosen by the day's own high — warm (hot) to
/// cool (Part I of the redesign spec), not tied to sky condition.
List<Color> _gradientFor(int high) {
  if (high >= 23) return const [Color(0xFFE2A33C), Color(0xFF6FB0E0)];
  if (high >= 21) return const [Color(0xFFD8A751), Color(0xFF6FB0E0)];
  if (high >= 19) return const [Color(0xFFC9A86A), Color(0xFF6FB0E0)];
  if (high >= 18) return const [Color(0xFFA8BCD0), Color(0xFF6FB0E0)];
  return const [Color(0xFF8FB6D8), Color(0xFF6FB0E0)];
}

class WeeklyForecastCard extends StatelessWidget {
  const WeeklyForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    // The range-bar scale spans the week's own min/max, not a hardcoded
    // range, so a colder or hotter week still uses the bar's full height.
    var scaleMax = _week.first.high;
    var scaleMin = _week.first.low;
    for (final day in _week.skip(1)) {
      if (day.high > scaleMax) scaleMax = day.high;
      if (day.low < scaleMin) scaleMin = day.low;
    }

    return SizedBox(
      height: 260,
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
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in _week) Expanded(child: _DayColumn(day: day, scaleMin: scaleMin, scaleMax: scaleMax)),
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

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.scaleMin, required this.scaleMax});

  final _Day day;
  final int scaleMin;
  final int scaleMax;

  bool get _isToday => day.label == 'Hoje';

  @override
  Widget build(BuildContext context) {
    final span = (scaleMax - scaleMin).toDouble();
    final topFraction = span == 0 ? 0.0 : (scaleMax - day.high) / span;
    final bottomFraction = span == 0 ? 0.0 : (day.low - scaleMin) / span;

    return Column(
      children: [
        Text(
          day.label,
          softWrap: false,
          style: TextStyle(
            fontSize: 16,
            fontWeight: _isToday ? FontWeight.w600 : FontWeight.w400,
            color: _isToday ? NocturneColors.text : NocturneColors.neutral500,
          ),
        ),
        const SizedBox(height: 8),
        Icon(_iconFor(day.sky), size: 22, color: _colorFor(day.sky)),
        const SizedBox(height: 8),
        Expanded(
          child: _RangeBar(topFraction: topFraction, bottomFraction: bottomFraction, gradientColors: _gradientFor(day.high)),
        ),
        const SizedBox(height: 8),
        Text('${day.high}°', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: NocturneColors.text)),
        Text('${day.low}°', style: TextStyle(fontSize: 14, color: NocturneColors.neutral600)),
      ],
    );
  }
}

/// A narrow vertical track with a gradient fill spanning from [topFraction]
/// (0 = top of the track) to `1 - bottomFraction` (measured from the
/// bottom) — the "how hot/cold this day is within the week" bar.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.topFraction, required this.bottomFraction, required this.gradientColors});

  final double topFraction;
  final double bottomFraction;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      decoration: BoxDecoration(color: NocturneColors.forecastTrack, borderRadius: BorderRadius.circular(4)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                top: height * topFraction,
                bottom: height * bottomFraction,
                left: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradientColors),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
