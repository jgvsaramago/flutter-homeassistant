import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/ha_history_point.dart';
import '../../theme/nocturne_theme.dart';

/// 24h line chart for one temperature series inside the Temperatures
/// sheet — the same `fl_chart`-based engine `TemperatureHistoryDialog` used
/// (real HA recorder history, not a hand-drawn mockup series), re-themed to
/// [NocturneColors]. Takes already-fetched [points] rather than fetching
/// its own — the enclosing section needs the same history to compute the
/// Hero's min/max line, so it fetches once and hands the result to both.
class TemperatureSheetChart extends StatelessWidget {
  const TemperatureSheetChart({super.key, required this.points, required this.seriesColor});

  final List<HaHistoryPoint>? points;
  final Color seriesColor;

  @override
  Widget build(BuildContext context) {
    final pts = points;
    if (pts == null || pts.length < 2) {
      return SizedBox(
        height: 130,
        child: Center(
          child: Text('Sem histórico suficiente', style: TextStyle(color: NocturneColors.neutral500, fontSize: 14, fontWeight: FontWeight.normal, decoration: TextDecoration.none)),
        ),
      );
    }
    return SizedBox(height: 130, child: _Chart(points: pts, color: seriesColor));
  }
}

const _weekdayAbbrev = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Rounds [value] down/up to the nearest multiple of [step] — used to make
/// both the axis bounds and the tick interval land on the same "nice" grid
/// (0.5°C steps for temperature, whole hours for time), so every generated
/// tick is automatically a nice value instead of some arbitrary fraction.
double _floorTo(double value, double step) => (value / step).floorToDouble() * step;
double _ceilTo(double value, double step) => (value / step).ceilToDouble() * step;

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.color});

  final List<HaHistoryPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [for (final p in points) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.value)];
    final values = points.map((p) => p.value);
    final dataMinX = spots.first.x;
    final maxX = spots.last.x;

    // Y axis: snap both the bounds and the interval to 0.5°C so every tick
    // is a whole or half degree — never something like 24.3° or 24.8°.
    const yStep = 0.5;
    final minY = _floorTo(values.reduce((a, b) => a < b ? a : b) - 0.5, yStep);
    final maxY = _ceilTo(values.reduce((a, b) => a > b ? a : b) + 0.5, yStep);
    final yInterval = _ceilTo((maxY - minY) / 4, yStep);

    // X axis: the chart's own minX is floored to the start of its hour so
    // fl_chart's evenly-spaced ticks (which always start at minX) land
    // exactly on the hour — e.g. 19:00, not 19:23. The plotted line still
    // uses the real data timestamps; only the axis's left bound moves,
    // leaving a small leading margin before the first real point.
    final dataMinDt = DateTime.fromMillisecondsSinceEpoch(dataMinX.round());
    final minX = DateTime(dataMinDt.year, dataMinDt.month, dataMinDt.day, dataMinDt.hour).millisecondsSinceEpoch.toDouble();
    const hourStep = 6;
    final xInterval = const Duration(hours: hourStep).inMilliseconds.toDouble();

    // The most recent local midnight within the plotted window, if any —
    // almost always present since the window spans a full 24h.
    final lastDt = DateTime.fromMillisecondsSinceEpoch(maxX.round());
    final midnight = DateTime(lastDt.year, lastDt.month, lastDt.day);
    final midnightX = midnight.millisecondsSinceEpoch.toDouble();
    final hasMidnightLine = midnightX >= minX && midnightX <= maxX;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        // fl_chart snaps its "nice interval" tick sequence to a baseline
        // that defaults to 0 (the Unix epoch, UTC) — with a UTC+1 local
        // offset, stepping by whole hours from that baseline lands on
        // :00 UTC, i.e. :00 local only when the offset happens to be a
        // multiple of the step. Anchoring the baseline to our own
        // already-hour-aligned minX makes every tick land exactly where
        // minX does, mod the interval — no drift.
        baselineX: minX,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: NocturneColors.neutral800, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (hasMidnightLine)
              VerticalLine(
                x: midnightX,
                color: NocturneColors.neutral600,
                strokeWidth: 1.5,
                dashArray: const [5, 6],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(color: NocturneColors.neutral500, fontSize: 12, fontWeight: FontWeight.normal, decoration: TextDecoration.none),
                  labelResolver: (_) => _weekdayAbbrev[midnight.weekday - 1],
                ),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yInterval,
              // Both default to true, which force-adds a label at the
              // exact axis min/max regardless of interval — since minY and
              // maxY only exist to pad the data range, that boundary tick
              // is rarely itself a clean multiple of yInterval, producing
              // an uneven-looking extra tick alongside the evenly-spaced
              // ones. The interval sequence alone is enough.
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(1)}°',
                style: TextStyle(color: NocturneColors.neutral500, fontSize: 12, fontWeight: FontWeight.normal, decoration: TextDecoration.none),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval,
              // maxX is the exact last data timestamp (not hour-aligned);
              // without this it'd add one extra, off-the-hour tick right
              // at the end — minX is already hour-aligned so including it
              // is both correct and harmless (it coincides with the first
              // interval tick).
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                final time = DateTime.fromMillisecondsSinceEpoch(value.round());
                final label = '${time.hour.toString().padLeft(2, '0')}:00';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: TextStyle(color: NocturneColors.neutral500, fontSize: 12, fontWeight: FontWeight.normal, decoration: TextDecoration.none)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => NocturneColors.neutral800,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}°\n'
                  '${DateTime.fromMillisecondsSinceEpoch(spot.x.round()).hour.toString().padLeft(2, '0')}:'
                  '${DateTime.fromMillisecondsSinceEpoch(spot.x.round()).minute.toString().padLeft(2, '0')}',
                  TextStyle(color: NocturneColors.text, fontSize: 13, fontWeight: FontWeight.normal, decoration: TextDecoration.none),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.16)),
          ),
        ],
      ),
    );
  }
}
