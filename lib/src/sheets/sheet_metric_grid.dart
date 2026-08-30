import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';

/// One row of [SheetMetricTile]'s info dialog: a band-coloured dot plus
/// its description (e.g. "até 800 ppm").
class SheetMetricPopoverRow {
  const SheetMetricPopoverRow({required this.color, required this.text});
  final Color color;
  final String text;
}

/// Everything one [SheetMetricTile] needs to render itself.
class SheetMetricData {
  const SheetMetricData({
    required this.label,
    required this.value,
    this.sub,
    this.color = NocturneColors.neutral300,
    this.meterFraction,
    this.popoverRows = const [],
  });

  final String label;
  final String value;
  final String? sub;
  final Color color;

  /// 0-1, clamped by the tile itself. Null omits the meter entirely — for
  /// metrics with no numeric scale (e.g. a weather condition string).
  final double? meterFraction;

  final List<SheetMetricPopoverRow> popoverRows;
}

/// A `repeat(3, 1fr)` grid of [SheetMetricTile]s. A count not divisible by
/// 3 leaves the last row's remaining columns empty rather than stretching
/// the final tile across them — e.g. 4 metrics puts one tile alone, left-
/// aligned, on the second row.
class SheetMetricGrid extends StatelessWidget {
  const SheetMetricGrid({super.key, required this.metrics});

  final List<SheetMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < metrics.length; start += 3) {
      final rowCount = (metrics.length - start).clamp(0, 3);
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: start + 3 < metrics.length ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 12),
                Expanded(child: col < rowCount ? SheetMetricTile(data: metrics[start + col]) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class SheetMetricTile extends StatelessWidget {
  const SheetMetricTile({super.key, required this.data});

  final SheetMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(color: NocturneColors.neutral900, borderRadius: BorderRadius.circular(NocturneRadii.smallCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.label.toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none, letterSpacing: 1.12, color: NocturneColors.neutral500),
                ),
              ),
              if (data.popoverRows.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showMetricInfo(context, data),
                  // Padding grows the tap target well past the icon's own
                  // 18px glyph — small icons on a wall panel need every bit
                  // of margin they can get without changing the visual size.
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.info_outline, size: 18, color: NocturneColors.neutral500),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, decoration: TextDecoration.none, height: 1.1, color: data.color),
          ),
          if (data.sub != null) ...[
            const SizedBox(height: 6),
            Text(data.sub!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral400)),
          ],
          if (data.meterFraction != null) ...[
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(top: 4), child: _Meter(fraction: data.meterFraction!, color: data.color)),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(height: 6, decoration: BoxDecoration(color: NocturneColors.neutral800, borderRadius: BorderRadius.circular(3))),
            Container(
              height: 6,
              width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ],
        );
      },
    );
  }
}

/// A centred modal explaining a metric's threshold bands — replaces an
/// earlier anchored-popover design that turned out unreliable (its
/// positioning broke depending on where in the sheet it was opened from).
/// A modal sidesteps that entirely: `showDialog`'s own barrier already
/// dismisses on an outside tap, and there's no anchoring math to get wrong.
void _showMetricInfo(BuildContext context, SheetMetricData data) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: NocturneSpacing.cardPadding,
          decoration: BoxDecoration(
            color: NocturneColors.surface,
            borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
            boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 20))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none, color: NocturneColors.text)),
              const SizedBox(height: 18),
              for (final row in data.popoverRows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: row.color, shape: BoxShape.circle)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          row.text,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral300),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
