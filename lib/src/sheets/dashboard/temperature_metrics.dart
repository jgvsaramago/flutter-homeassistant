import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';
import '../sheet_metric_grid.dart';

/// One threshold band for a [MetricSpec]: everything up to [upperBound]
/// (exclusive) falls in this band; the last band in a spec's list should
/// have `upperBound: null` to catch everything above the previous one.
class MetricBand {
  const MetricBand({required this.upperBound, required this.color, required this.label, required this.description});

  final double? upperBound;
  final Color color;

  /// Shown as the tile's sub-label (e.g. "bom") and, capitalized, as the
  /// popover row's leading word.
  final String label;

  /// The popover row's full description (e.g. "até 800 ppm").
  final String description;
}

/// The static shape of one metric: its unit, decimal precision, meter
/// scale, and threshold bands. Values themselves come from a live HA
/// entity (see `TemperatureEntityConfig`) — this only describes how to
/// interpret and colour whatever value shows up.
class MetricSpec {
  const MetricSpec({required this.label, required this.unit, required this.decimals, required this.bands, this.meterMax});

  final String label;
  final String unit;
  final int decimals;
  final List<MetricBand> bands;

  /// Denominator for the meter fill (`value / meterMax`, clamped to
  /// [0, 1]). Null omits the meter — used for metrics with no simple
  /// linear scale (pressure) or none at all (weather state).
  final double? meterMax;

  MetricBand bandFor(double value) {
    for (final band in bands) {
      if (band.upperBound == null || value < band.upperBound!) return band;
    }
    return bands.last;
  }
}

String _formatPt(double value, int decimals) => value.toStringAsFixed(decimals).replaceAll('.', ',');

/// Builds the [SheetMetricData] a [SheetMetricGrid] tile needs from a raw
/// numeric reading — the one place a value turns into a colour, a
/// sub-label, and a meter fraction, all derived from the same band table
/// so they can never disagree with each other.
SheetMetricData buildMetric(MetricSpec spec, double? rawValue) {
  if (rawValue == null) {
    return SheetMetricData(label: spec.label, value: '--', color: NocturneColors.neutral400);
  }
  final band = spec.bandFor(rawValue);
  return SheetMetricData(
    label: spec.label,
    value: '${_formatPt(rawValue, spec.decimals)} ${spec.unit}'.trim(),
    sub: band.label,
    color: band.color,
    meterFraction: spec.meterMax == null ? null : (rawValue / spec.meterMax!).clamp(0.0, 1.0),
    popoverRows: [for (final b in spec.bands) SheetMetricPopoverRow(color: b.color, text: '${_capitalize(b.label)} · ${b.description}')],
  );
}

/// For non-numeric readings (the weather-state tile) — no band, no meter,
/// no colour-coding, just the raw text.
SheetMetricData buildTextMetric(String label, String? text) {
  return SheetMetricData(label: label, value: (text == null || text.isEmpty) ? '--' : text, color: NocturneColors.neutral300);
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// Health/air-quality metrics escalate green → amber → red, mirroring the
// CO₂ threshold model `ClimateModeRow` already uses. Weather metrics
// (rain/wind/gust) keep one fixed hue across all three bands — they're
// informational, not a health alarm — matching the design reference.

final co2Spec = MetricSpec(
  label: 'CO₂',
  unit: 'ppm',
  decimals: 0,
  meterMax: 1600,
  bands: [
    MetricBand(upperBound: 800, color: NocturneColors.green, label: 'bom', description: 'até 800 ppm'),
    MetricBand(upperBound: 1200, color: NocturneColors.amber, label: 'médio', description: '800–1200 ppm'),
    MetricBand(upperBound: null, color: NocturneColors.red, label: 'alto', description: '> 1200 ppm'),
  ],
);

final pm25Spec = MetricSpec(
  label: 'PM2.5',
  unit: 'µg/m³',
  decimals: 0,
  meterMax: 35,
  bands: [
    MetricBand(upperBound: 12, color: NocturneColors.green, label: 'bom', description: 'até 12 µg/m³'),
    MetricBand(upperBound: 35, color: NocturneColors.amber, label: 'médio', description: '12–35 µg/m³'),
    MetricBand(upperBound: null, color: NocturneColors.red, label: 'alto', description: '> 35 µg/m³'),
  ],
);

final vocSpec = MetricSpec(
  label: 'VOC',
  unit: 'mg/m³',
  decimals: 1,
  meterMax: 1.0,
  bands: [
    MetricBand(upperBound: 0.3, color: NocturneColors.green, label: 'bom', description: 'até 0,3 mg/m³'),
    MetricBand(upperBound: 1.0, color: NocturneColors.amber, label: 'médio', description: '0,3–1,0 mg/m³'),
    MetricBand(upperBound: null, color: NocturneColors.red, label: 'alto', description: '> 1,0 mg/m³'),
  ],
);

final radonSpec = MetricSpec(
  label: 'Radão',
  unit: 'Bq/m³',
  decimals: 0,
  meterMax: 300,
  bands: [
    MetricBand(upperBound: 100, color: NocturneColors.green, label: 'bom', description: 'até 100 Bq/m³'),
    MetricBand(upperBound: 300, color: NocturneColors.amber, label: 'médio', description: '100–300 Bq/m³'),
    MetricBand(upperBound: null, color: NocturneColors.red, label: 'alto', description: '> 300 Bq/m³'),
  ],
);

final rainSpec = MetricSpec(
  label: 'Chuva hoje',
  unit: 'mm',
  decimals: 1,
  meterMax: 10,
  bands: [
    MetricBand(upperBound: 2.5, color: NocturneColors.blue, label: 'fraca', description: 'Fraca até 2,5 mm'),
    MetricBand(upperBound: 10, color: NocturneColors.blue, label: 'moderada', description: 'Moderada 2,5–10 mm'),
    MetricBand(upperBound: null, color: NocturneColors.blue, label: 'forte', description: 'Forte > 10 mm'),
  ],
);

final windSpec = MetricSpec(
  label: 'Vento',
  unit: 'km/h',
  decimals: 0,
  meterMax: 40,
  bands: [
    MetricBand(upperBound: 20, color: NocturneColors.blue, label: 'calmo', description: 'Calmo até 20 km/h'),
    MetricBand(upperBound: 40, color: NocturneColors.blue, label: 'moderado', description: 'Moderado 20–40 km/h'),
    MetricBand(upperBound: null, color: NocturneColors.blue, label: 'forte', description: 'Forte > 40 km/h'),
  ],
);

final gustSpec = MetricSpec(
  label: 'Rajada máx.',
  unit: 'km/h',
  decimals: 0,
  meterMax: 60,
  bands: [
    MetricBand(upperBound: 20, color: NocturneColors.blue, label: 'calmo', description: 'Calmo até 20 km/h'),
    MetricBand(upperBound: 40, color: NocturneColors.blue, label: 'moderado', description: 'Moderado 20–40 km/h'),
    MetricBand(upperBound: null, color: NocturneColors.blue, label: 'forte', description: 'Forte > 40 km/h'),
  ],
);

// Pressure's meter has no simple linear scale in the reference material,
// so unlike every other metric here, `buildMetric` for pressure is used
// with `meterMax: null` — no meter is drawn, per §2.5's "omit when the
// metric has no numeric scale" rule.
final pressureSpec = MetricSpec(
  label: 'Pressão',
  unit: 'hPa',
  decimals: 0,
  bands: [
    MetricBand(upperBound: 1000, color: NocturneColors.neutral300, label: 'baixa', description: 'Baixa < 1000 hPa'),
    MetricBand(upperBound: 1020, color: NocturneColors.neutral300, label: 'normal', description: 'Normal 1000–1020 hPa'),
    MetricBand(upperBound: null, color: NocturneColors.neutral300, label: 'alta', description: 'Alta > 1020 hPa'),
  ],
);

final uvSpec = MetricSpec(
  label: 'Índice UV',
  unit: '',
  decimals: 0,
  meterMax: 11,
  bands: [
    MetricBand(upperBound: 3, color: NocturneColors.green, label: 'baixo', description: 'Baixo 0–2'),
    MetricBand(upperBound: 6, color: NocturneColors.amber, label: 'moderado', description: 'Moderado 3–5'),
    MetricBand(upperBound: null, color: NocturneColors.red, label: 'alto', description: 'Alto ≥ 6'),
  ],
);
