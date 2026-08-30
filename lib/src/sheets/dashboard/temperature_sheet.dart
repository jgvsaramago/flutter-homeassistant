import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../models/ha_history_point.dart';
import '../../providers/ha_providers.dart';
import '../../providers/temperature_entities_provider.dart';
import '../../theme/nocturne_theme.dart';
import '../sheet.dart';
import '../sheet_ai_summary.dart';
import '../sheet_metric_grid.dart';
import '../sheet_parts.dart';
import 'temperature_metrics.dart';
import 'temperature_sheet_chart.dart';

/// Opens the Temperatures sheet: interior and exterior readings, each with
/// a 24h chart and its own grid of air-quality/weather metrics, plus a
/// static "about today" summary at the top (see the note on
/// [_aiSummaryBody] — there's no AI integration behind it yet).
Future<void> showTemperatureSheet(BuildContext context) {
  return showSheet<void>(
    context,
    children: const [
      SheetHandle(),
      _AiSummary(),
      _InteriorSection(),
      SizedBox(height: 34),
      _ExteriorSection(),
    ],
  );
}

double? _readNumber(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

String? _readText(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return entity.state;
}

String _formatTemp(double celsius) => celsius.toStringAsFixed(1).replaceAll('.', ',');

// This app has no AI/LLM integration yet (see `showTemperatureSheet`'s own
// doc) — this copy is static placeholder content, the same treatment the
// energy card gives its un-wired appliance readings, until there's an
// actual model/service behind it. The reference material describes a third
// suggestion row "per the live source" without giving its text, so only
// the two fully-specified suggestions are included here.
class _AiSummary extends StatelessWidget {
  const _AiSummary();

  @override
  Widget build(BuildContext context) {
    return const SheetAiSummary(
      title: 'Sobre hoje',
      body:
          'O ar interior manteve-se bom todo o dia — CO₂ abaixo de 700 ppm e '
          'PM2.5 estável. Fora, a manhã foi fria e húmida e a tarde chegou '
          'aos 21 °C com chuva fraca.',
      suggestionsTitle: 'Sugestões',
      suggestions: [
        SheetAiSuggestion(text: 'Abrir as janelas — ar exterior mais seco', timing: '15h às 18h'),
        SheetAiSuggestion(text: 'Manter os estores a sul fechados', timing: 'até às 17h'),
      ],
    );
  }
}

class _InteriorSection extends ConsumerWidget {
  const _InteriorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final config = ref.watch(temperatureEntityConfigProvider);

    return _TemperatureSection(
      title: 'Interior',
      meta: 'Sala',
      tempEntityId: config.interiorTempEntityId,
      seriesColor: NocturneColors.accent,
      humidity: _readNumber(entities, config.interiorHumidityEntityId),
      metrics: [
        buildMetric(co2Spec, _readNumber(entities, config.co2EntityId)),
        buildMetric(pm25Spec, _readNumber(entities, config.pm25EntityId)),
        buildMetric(vocSpec, _readNumber(entities, config.vocEntityId)),
        buildMetric(radonSpec, _readNumber(entities, config.radonEntityId)),
      ],
    );
  }
}

class _ExteriorSection extends ConsumerWidget {
  const _ExteriorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final config = ref.watch(temperatureEntityConfigProvider);

    return _TemperatureSection(
      title: 'Exterior',
      meta: 'Estação do jardim',
      tempEntityId: config.exteriorTempEntityId,
      seriesColor: NocturneColors.solarMark,
      humidity: _readNumber(entities, config.exteriorHumidityEntityId),
      metrics: [
        buildMetric(rainSpec, _readNumber(entities, config.rainEntityId)),
        buildMetric(windSpec, _readNumber(entities, config.windEntityId)),
        buildMetric(gustSpec, _readNumber(entities, config.gustEntityId)),
        buildMetric(pressureSpec, _readNumber(entities, config.pressureEntityId)),
        buildMetric(uvSpec, _readNumber(entities, config.uvEntityId)),
        buildTextMetric('Estado', _readText(entities, config.weatherStateEntityId)),
      ],
    );
  }
}

/// One "Interior"/"Exterior" block: header, hero reading, 24h chart, metric
/// grid. Fetches its own temperature entity's 24h history once (for both
/// the chart and the hero's min/max line, so they can't disagree) and
/// re-fetches only if the configured entity id itself changes.
class _TemperatureSection extends ConsumerStatefulWidget {
  const _TemperatureSection({
    required this.title,
    required this.meta,
    required this.tempEntityId,
    required this.seriesColor,
    required this.humidity,
    required this.metrics,
  });

  final String title;
  final String meta;
  final String? tempEntityId;
  final Color seriesColor;
  final double? humidity;
  final List<SheetMetricData> metrics;

  @override
  ConsumerState<_TemperatureSection> createState() => _TemperatureSectionState();
}

class _TemperatureSectionState extends ConsumerState<_TemperatureSection> {
  Future<List<HaHistoryPoint>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TemperatureSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tempEntityId != widget.tempEntityId) setState(_load);
  }

  void _load() {
    final entityId = widget.tempEntityId;
    _future = entityId == null
        ? null
        : ref.read(haWebSocketClientProvider).historyDuringPeriod(entityId, start: DateTime.now().subtract(const Duration(hours: 24)));
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final current = _readNumber(entities, widget.tempEntityId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetSectionHeader(title: widget.title, meta: widget.meta),
        FutureBuilder<List<HaHistoryPoint>>(
          future: _future,
          builder: (context, snapshot) {
            final points = snapshot.data;
            String? minmax;
            if (points != null && points.length >= 2) {
              final values = points.map((p) => p.value);
              final lo = values.reduce((a, b) => a < b ? a : b);
              final hi = values.reduce((a, b) => a > b ? a : b);
              minmax = 'mín ${_formatTemp(lo)} °C · máx ${_formatTemp(hi)} °C';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHero(
                  value: current == null ? '--' : _formatTemp(current),
                  unit: '°C',
                  aside: widget.humidity == null ? null : '${widget.humidity!.round()}% humidade',
                  minmax: minmax,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 26),
                  child: TemperatureSheetChart(points: points, seriesColor: widget.seriesColor),
                ),
              ],
            );
          },
        ),
        SheetMetricGrid(metrics: widget.metrics),
      ],
    );
  }
}
