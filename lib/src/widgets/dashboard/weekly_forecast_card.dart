import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/weekly_forecast_provider.dart';
import '../../theme/nocturne_theme.dart';

enum _Sky { sunny, partlyCloudy, cloudy, rainy, unknown }

/// Maps HA's weather condition strings (see the `weather` integration docs)
/// to this card's four visual buckets — `unknown` covers both "no data yet"
/// (unconfigured/unavailable entity) and any condition string this app
/// doesn't have its own icon for.
_Sky _skyFor(String? condition) => switch (condition) {
  'sunny' || 'clear-night' => _Sky.sunny,
  'partlycloudy' => _Sky.partlyCloudy,
  'cloudy' || 'fog' || 'windy' || 'windy-variant' => _Sky.cloudy,
  'rainy' || 'pouring' || 'snowy' || 'snowy-rainy' || 'hail' || 'lightning' || 'lightning-rainy' || 'exceptional' => _Sky.rainy,
  _ => _Sky.unknown,
};

IconData _iconFor(_Sky sky) => switch (sky) {
  _Sky.sunny => Icons.wb_sunny_outlined,
  _Sky.partlyCloudy => Icons.wb_cloudy_outlined,
  _Sky.cloudy => Icons.cloud_outlined,
  _Sky.rainy => Icons.umbrella_outlined,
  _Sky.unknown => Icons.help_outline,
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
  _Sky.unknown => NocturneColors.neutral600,
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

/// Section 5 of the Homepage: 7-day forecast, from whatever `weather.*`
/// entity Settings → Temperaturas has configured (see
/// `weeklyForecastProvider`). Shows "--" per day, same as every other
/// unconfigured metric in this app, until that's set.
class WeeklyForecastCard extends ConsumerWidget {
  const WeeklyForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.valueOrNull`, not `.value`: a transient fetch error (or the very
    // first frame, before the notifier's future resolves) must not crash
    // this card — it should just show "--" until data (or a retry) arrives.
    final week = ref.watch(weeklyForecastProvider).valueOrNull ?? const [];

    // The range-bar scale spans the week's own min/max among days that
    // actually have data — a colder or hotter week still uses the bar's
    // full height, and an empty/unconfigured week just skips every fill.
    final knownHighs = [for (final d in week) ?d.high];
    final knownLows = [for (final d in week) ?d.low];
    final hasRange = knownHighs.isNotEmpty && knownLows.isNotEmpty;
    final scaleMax = hasRange ? knownHighs.reduce((a, b) => a > b ? a : b) : 0;
    final scaleMin = hasRange ? knownLows.reduce((a, b) => a < b ? a : b) : 0;

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
                    for (final day in week) Expanded(child: _DayColumn(day: day, scaleMin: scaleMin, scaleMax: scaleMax)),
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

  final WeeklyForecastDay day;
  final int scaleMin;
  final int scaleMax;

  bool get _isToday => day.label == 'Hoje';

  @override
  Widget build(BuildContext context) {
    final high = day.high;
    final low = day.low;
    final hasData = high != null && low != null && scaleMax > scaleMin;
    final sky = _skyFor(day.condition);

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
        Icon(_iconFor(sky), size: 22, color: _colorFor(sky)),
        const SizedBox(height: 8),
        Expanded(
          child: hasData
              ? _RangeBar(
                  topFraction: (scaleMax - high) / (scaleMax - scaleMin),
                  bottomFraction: (low - scaleMin) / (scaleMax - scaleMin),
                  gradientColors: _gradientFor(high),
                )
              : const _RangeBar(topFraction: null, bottomFraction: null, gradientColors: []),
        ),
        const SizedBox(height: 8),
        Text('${high ?? '--'}°', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: NocturneColors.text)),
        Text('${low ?? '--'}°', style: TextStyle(fontSize: 14, color: NocturneColors.neutral600)),
      ],
    );
  }
}

/// A narrow vertical track with a gradient fill spanning from [topFraction]
/// (0 = top of the track) to `1 - bottomFraction` (measured from the
/// bottom) — the "how hot/cold this day is within the week" bar. Null
/// fractions render the bare track with no fill, for a day with no data.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.topFraction, required this.bottomFraction, required this.gradientColors});

  final double? topFraction;
  final double? bottomFraction;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    final top = topFraction;
    final bottom = bottomFraction;

    return Container(
      width: 8,
      decoration: BoxDecoration(color: NocturneColors.forecastTrack, borderRadius: BorderRadius.circular(4)),
      child: top == null || bottom == null
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return Stack(
                  children: [
                    Positioned(
                      top: height * top,
                      bottom: height * bottom,
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
