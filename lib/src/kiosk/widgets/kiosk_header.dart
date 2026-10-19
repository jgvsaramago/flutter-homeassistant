import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/weekly_forecast_provider.dart';
import '../data/calendar_data.dart';
import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';

/// Ticks once a minute, on the minute — drives the clock and anything that
/// depends on "now" (the calendar's now-line, today's highlights).
final minuteTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  while (true) {
    final now = DateTime.now();
    await Future<void>.delayed(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond));
    yield DateTime.now();
  }
});

DateTime watchNow(WidgetRef ref) => ref.watch(minuteTickProvider).valueOrNull ?? DateTime.now();

/// The header shared by every page (the design's "Cabeçalho"): a big clock
/// with the date and a 3-day forecast on Início, a compact single row
/// elsewhere. It's one persistent widget, so moving between pages animates
/// between the two layouts instead of swapping them.
class KioskHeader extends ConsumerWidget {
  const KioskHeader({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchNow(ref);
    final weather = ref.watch(weatherNowProvider);
    final forecast = ref.watch(weeklyForecastProvider).valueOrNull ?? const <WeeklyForecastDay>[];
    final holiday = ref.watch(nextHolidayProvider).valueOrNull;

    final week = 'Semana ${PtDates.isoWeek(now)}';
    String sub = week;
    if (holiday != null) {
      final d = holiday.start;
      sub = '$week · Próximo feriado: ${holiday.title}, ${PtDates.abbrLower[d.weekday - 1]} ${d.day} ${PtDates.months[d.month - 1].substring(0, 3)}';
    }
    final today = forecast.isNotEmpty ? forecast.first : null;
    final range = [if (today?.high != null) 'Máx ${today!.high}°', if (today?.low != null) 'Mín ${today!.low}°'].join(' · ');

    return TweenAnimationBuilder<double>(
      tween: Tween(end: compact ? 1 : 0),
      duration: const Duration(milliseconds: 550),
      curve: kEase,
      builder: (context, t, _) {
        double l(double full, double small) => lerpDouble(full, small, t)!;
        // Compact layout, as in the design: the date sits 65 px after the
        // clock (Outfit's digits are proportional, so the clock's width —
        // and the design's fixed 280 px — only line up at 08:42), and the
        // temperature sits 20 px before the condition/min-max text.
        final clockW = _textWidth(PtDates.hm(now), KText.d(88, spacing: -3));
        final weatherW = math.max(_textWidth(weatherLabel(weather.condition), KText.s(20, weight: FontWeight.w500)), _textWidth(range, KText.s(20)));
        final compactTextLeft = clockW + 65;
        final compactWeatherRight = weatherW + 20;
        return SizedBox(
          width: 1328,
          height: l(252, 100),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: l(0, 10),
                child: Text(PtDates.hm(now), style: KText.d(l(168, 88), spacing: l(-6, -3), height: 0.9)),
              ),
              Positioned(
                left: l(0, compactTextLeft),
                top: l(166, 12),
                child: Text(PtDates.long(now), style: KText.s(l(36, 30), weight: FontWeight.w600)),
              ),
              Positioned(
                left: l(0, compactTextLeft),
                top: l(216, 58),
                child: Text(t < 0.5 ? sub : week, style: KText.s(l(24, 22), color: KColors.muted)),
              ),
              Positioned(
                right: l(376, compactWeatherRight),
                top: l(30, 18),
                child: Row(
                  children: [
                    KIcon(weatherIcon(weather.condition), size: l(84, 56), stroke: 1.5),
                    SizedBox(width: l(18, 16)),
                    Text(
                      weather.temp == null ? '--°' : '${weather.temp!.round()}°',
                      style: KText.d(l(104, 64), weight: FontWeight.w400, height: 1, spacing: l(-3, -1)),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: l(376, 0),
                top: l(150, 20),
                child: Text(weatherLabel(weather.condition), style: KText.s(l(24, 20), weight: FontWeight.w500)),
              ),
              Positioned(
                right: l(376, 0),
                top: l(190, 50),
                child: Text(range, style: KText.s(l(22, 20), color: KColors.muted)),
              ),
              if (t < 1)
                Positioned(
                  right: 0,
                  top: l(104, 0),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: l(1, 0.85),
                        alignment: Alignment.topRight,
                        child: Row(
                          children: [
                            for (final (i, day) in forecast.skip(1).take(3).indexed) ...[if (i > 0) const SizedBox(width: 12), _ForecastTile(day: day)],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ForecastTile extends StatelessWidget {
  const _ForecastTile({required this.day});

  final WeeklyForecastDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Text(
            day.label,
            style: KText.s(18, weight: FontWeight.w500, color: KColors.muted),
          ),
          const SizedBox(height: 10),
          KIcon(weatherIcon(day.condition), size: 36, stroke: 1.7),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(day.high == null ? '--' : '${day.high}°', style: KText.s(22, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                day.low == null ? '--' : '${day.low}°',
                style: KText.s(18, weight: FontWeight.w500, color: KColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _textWidth(String text, TextStyle style) {
  if (text.isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}
