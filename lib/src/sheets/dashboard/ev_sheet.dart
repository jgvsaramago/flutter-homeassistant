import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ev_cars_provider.dart';
import '../../providers/ha_providers.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/dashboard/calendar_grid.dart' show monthNamesPt;
import '../sheet.dart';
import '../sheet_parts.dart';

/// Opens the EV sheet for one of the Homepage's two car slots: charge
/// state, this month's energy/cost, a 6-month bar history, the energy mix
/// that fed the charging, and the last charging sessions — see
/// `EvCarsRow` for the entry cards that open this.
Future<void> showEvSheet(BuildContext context, CarSide side) {
  return showSheet<void>(context, children: [_EvSheetBody(side: side)]);
}

double? _readNumber(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

const _truthyStates = {
  'on',
  'true',
  '1',
  'yes',
  'charging',
  'connected',
  'plugged_in',
  'plugged',
};

bool? _readBoolState(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return _truthyStates.contains(entity.state.toLowerCase());
}

/// SoC bar fill: green while charging, blue while just plugged in (cable
/// connected but not drawing current — a full battery stays plugged in
/// without charging, so this is worth distinguishing from truly idle),
/// neutral otherwise. Same rule as the home card's own `_socBarColor`.
Color _socBarColor(bool charging, bool? plugged) {
  if (charging) return NocturneColors.green;
  if (plugged == true) return NocturneColors.blue;
  return NocturneColors.neutral500;
}

/// `null`/blank means "no photo configured", distinct from a URL that's
/// merely unreachable (which `Image.network`'s own `errorBuilder` handles).
String? _normalizedUrl(String? url) =>
    (url == null || url.trim().isEmpty) ? null : url.trim();

String _euro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

String _kwh(double v) => '${v.round()} kWh';

/// One bar of the 6-month chart, fully resolved (colours included) — mirrors
/// the reference's `bars.map(...)` in `evView()`.
class _Bar {
  const _Bar({
    required this.label,
    required this.value,
    required this.price,
    required this.heightPx,
    required this.accent,
  });
  final String label;
  final int value;
  final String price;
  final double heightPx;
  final bool accent;
}

class _OriginSegment {
  const _OriginSegment({
    required this.label,
    required this.share,
    required this.color,
  });
  final String label;
  final int share;
  final Color color;
}

class _Session {
  const _Session({
    required this.date,
    required this.kwh,
    required this.eur,
    required this.src,
    required this.color,
  });
  final String date;
  final String kwh;
  final String eur;
  final String src;
  final Color color;
}

/// Placeholder monthly/mix/session data — this app has no per-source (solar
/// vs battery vs grid) attribution for EV charging specifically, nor a
/// history backend for past months' totals or a charging-session log (the
/// live entities configured in Settings only ever report *now*). Same
/// treatment as `WeeklyForecastCard`'s static week: real numbers wherever a
/// live entity exists (state of charge, range, charging/plug state, this
/// month's energy/cost and their deltas — see `_EvSheetBody`), static
/// placeholder for the rest until a real integration can back it.
class _Placeholder {
  const _Placeholder({
    required this.energyKwh,
    required this.costEur,
    required this.energyDeltaPct,
    required this.costDeltaEur,
    required this.bars,
    required this.origin,
    required this.sessions,
  });

  final double energyKwh;
  final double costEur;
  final double energyDeltaPct;
  final double costDeltaEur;

  /// Five historical (kWh, price€) pairs, oldest first — the sixth/current
  /// month comes from live data (or this same placeholder as a fallback),
  /// appended in [_buildBars].
  final List<(double, double)> bars;
  final List<_OriginSegment> origin;
  final List<_Session> sessions;
}

final _placeholderLeft = _Placeholder(
  energyKwh: 142,
  costEur: 21.30,
  energyDeltaPct: 17,
  costDeltaEur: 2.80,
  bars: [(96, 14.40), (88, 13.20), (104, 15.60), (120, 18.00), (121, 18.50)],
  origin: [
    _OriginSegment(label: 'Solar', share: 54, color: NocturneColors.solarMark),
    _OriginSegment(
      label: 'Bateria',
      share: 18,
      color: NocturneColors.batteryMark,
    ),
    _OriginSegment(label: 'Rede', share: 28, color: NocturneColors.gridMark),
  ],
  sessions: [
    _Session(
      date: '22 ago · 23:10',
      kwh: '38 kWh',
      eur: '4,20 €',
      src: 'solar + rede',
      color: NocturneColors.solarMark,
    ),
    _Session(
      date: '19 ago · 22:40',
      kwh: '41 kWh',
      eur: '6,15 €',
      src: 'rede',
      color: NocturneColors.gridMark,
    ),
    _Session(
      date: '15 ago · 13:05',
      kwh: '29 kWh',
      eur: '1,90 €',
      src: 'solar',
      color: NocturneColors.solarMark,
    ),
  ],
);

final _placeholderRight = _Placeholder(
  energyKwh: 64,
  costEur: 9.60,
  energyDeltaPct: -18,
  costDeltaEur: -2.40,
  bars: [(60, 9.00), (72, 10.80), (66, 9.90), (80, 12.00), (78, 11.70)],
  origin: [
    _OriginSegment(label: 'Solar', share: 48, color: NocturneColors.solarMark),
    _OriginSegment(
      label: 'Bateria',
      share: 12,
      color: NocturneColors.batteryMark,
    ),
    _OriginSegment(label: 'Rede', share: 40, color: NocturneColors.gridMark),
  ],
  sessions: [
    _Session(
      date: '18 ago · 21:20',
      kwh: '34 kWh',
      eur: '5,10 €',
      src: 'rede',
      color: NocturneColors.gridMark,
    ),
    _Session(
      date: '11 ago · 12:30',
      kwh: '30 kWh',
      eur: '2,20 €',
      src: 'solar',
      color: NocturneColors.solarMark,
    ),
  ],
);

/// The last 6 calendar months' lowercase pt-PT abbreviations, ending at the
/// current month — e.g. run in August: mar, abr, mai, jun, jul, ago.
List<String> _last6MonthLabels(DateTime now) {
  return [
    for (var i = 5; i >= 0; i--)
      monthNamesPt[(now.month - 1 - i + 24) % 12].substring(0, 3),
  ];
}

List<_Bar> _buildBars(
  _Placeholder placeholder,
  double currentKwh,
  double currentCostEur,
  List<String> labels,
) {
  final values = [...placeholder.bars.map((b) => b.$1), currentKwh];
  final max = values.reduce((a, b) => a > b ? a : b);
  return [
    for (var i = 0; i < 6; i++)
      _Bar(
        label: labels[i],
        value: (i < 5 ? placeholder.bars[i].$1 : currentKwh).round(),
        price: _euro(i < 5 ? placeholder.bars[i].$2 : currentCostEur),
        heightPx: (values[i] / max * 168).roundToDouble(),
        accent: i == 5,
      ),
  ];
}

class _EvSheetBody extends ConsumerWidget {
  const _EvSheetBody({required this.side});

  final CarSide side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entitiesProvider).value ?? const {};
    final car = ref.watch(evCarsConfigProvider).forSide(side);
    final stopped = ref.watch(evChargeStoppedProvider(side));
    final placeholder = side == CarSide.left
        ? _placeholderLeft
        : _placeholderRight;
    final now = DateTime.now();

    final rawCharging = _readBoolState(entities, car.chargingEntityId) ?? false;
    final charging = rawCharging && !stopped;
    final plugged = _readBoolState(entities, car.plugConnectedEntityId);
    final soc = _readNumber(entities, car.batterySocEntityId) ?? 0;
    final rangeEntity = car.rangeEntityId == null
        ? null
        : entities[car.rangeEntityId];
    final range = _readNumber(entities, car.rangeEntityId);
    final rangeUnit = rangeEntity?.unitOfMeasurement ?? 'km';

    final energyKwh =
        _readNumber(entities, car.monthEnergyEntityId) ?? placeholder.energyKwh;
    final costEur =
        _readNumber(entities, car.monthCostEntityId) ?? placeholder.costEur;
    final energyDeltaPct =
        _readNumber(entities, car.monthEnergyDeltaEntityId) ??
        placeholder.energyDeltaPct;
    final costDeltaEur =
        _readNumber(entities, car.monthCostDeltaEntityId) ??
        placeholder.costDeltaEur;

    final statusColor = charging
        ? NocturneColors.green
        : NocturneColors.neutral500;
    final monthName = monthNamesPt[now.month - 1];
    final prevMonthName = monthNamesPt[(now.month - 2 + 12) % 12];

    final energyDeltaText =
        '${energyDeltaPct >= 0 ? '+' : '−'}${energyDeltaPct.abs().round()}% vs $prevMonthName';
    final costDeltaText =
        '${costDeltaEur >= 0 ? '+' : '−'}${_euro(costDeltaEur.abs())} vs $prevMonthName';

    final bars = _buildBars(
      placeholder,
      energyKwh,
      costEur,
      _last6MonthLabels(now),
    );
    // origin kWh per segment, derived from its share of this month's total
    // energy — keeps the legend's kWh figures consistent with the live
    // energy value instead of a second, independently-static number.
    final originKwh = [
      for (final o in placeholder.origin) (energyKwh * o.share / 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        _Header(
          name: car.name,
          statusColor: statusColor,
          status: charging ? 'A carregar · faltam 45 min' : 'Sem carregamento',
          soc: soc,
          rangeLabel: range == null ? '--' : '${range.round()} $rangeUnit',
          photoUrl: _normalizedUrl(car.photoUrl),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: _SocBar(soc: soc, color: _socBarColor(charging, plugged)),
        ),
        if (charging)
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: _StopChargeButton(
              onTap: () =>
                  ref.read(evChargeStoppedProvider(side).notifier).state = true,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Energia · $monthName',
                  value: _kwh(energyKwh),
                  delta: energyDeltaText,
                  deltaColor: energyDeltaPct >= 0
                      ? NocturneColors.green
                      : NocturneColors.neutral400,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  label: 'Custo · $monthName',
                  value: _euro(costEur),
                  delta: costDeltaText,
                  deltaColor: NocturneColors.neutral400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 208, child: _BarChart(bars: bars)),
        Padding(
          padding: EdgeInsets.fromLTRB(4, 30, 4, 14),
          child: Text(
            'Origem da carga',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
              color: NocturneColors.text,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _OriginBar(origin: placeholder.origin),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: _OriginLegend(origin: placeholder.origin, kwh: originKwh),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            'Últimas sessões',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
              color: NocturneColors.text,
            ),
          ),
        ),
        for (final s in placeholder.sessions) _SessionRow(session: s),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.statusColor,
    required this.status,
    required this.soc,
    required this.rangeLabel,
    required this.photoUrl,
  });

  final String name;
  final Color statusColor;
  final String status;
  final double soc;
  final String rangeLabel;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 2.04,
                    decoration: TextDecoration.none,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: -0.8,
                    decoration: TextDecoration.none,
                    color: NocturneColors.text,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${soc.round()}%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        decoration: TextDecoration.none,
                        color: NocturneColors.text,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: 17,
                        decoration: TextDecoration.none,
                        color: NocturneColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _CarPhoto(url: photoUrl, width: 300, height: 170, radius: 16),
        ],
      ),
    );
  }
}

/// The header's 300×170 photo slot: [url] if it loads, else the dashed-look
/// "foto do carro" placeholder — same fallback shape as the home card's own
/// `_CarPhoto` in `ev_cars_row.dart`, just at the sheet's own fixed size.
class _CarPhoto extends ConsumerWidget {
  const _CarPhoto({
    required this.url,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = this.url;
    final connectionConfig = url == null ? null : ref.watch(connectionConfigProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _PhotoPlaceholder(radius: radius)
            : Image.network(
                url,
                fit: BoxFit.cover,
                headers: haImageAuthHeaders(connectionConfig, url),
                errorBuilder: (context, error, stackTrace) =>
                    _PhotoPlaceholder(radius: radius),
              ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: NocturneColors.neutral700),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 26,
            color: NocturneColors.neutral600,
          ),
          SizedBox(height: 8),
          Text(
            'foto do carro',
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.none,
              color: NocturneColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocBar extends StatelessWidget {
  const _SocBar({required this.soc, required this.color});

  final double soc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: NocturneColors.neutral800,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 8,
              width: constraints.maxWidth * (soc / 100).clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StopChargeButton extends StatelessWidget {
  const _StopChargeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NocturneRadii.pill),
          border: Border.all(color: NocturneColors.accent),
        ),
        child: Text(
          'Parar carga',
          style: TextStyle(
            fontSize: 19,
            decoration: TextDecoration.none,
            color: NocturneColors.accent,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaColor,
  });

  final String label;
  final String value;
  final String delta;
  final Color deltaColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: NocturneColors.neutral900,
        borderRadius: BorderRadius.circular(NocturneRadii.insetPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 1.5,
              decoration: TextDecoration.none,
              color: NocturneColors.neutral500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              height: 1,
              decoration: TextDecoration.none,
              color: NocturneColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            delta,
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              color: deltaColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars});

  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _BarColumn(bar: bars[i])),
          ],
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.bar});

  final _Bar bar;

  @override
  Widget build(BuildContext context) {
    final valueColor = bar.accent
        ? NocturneColors.bg
        : NocturneColors.neutral200;
    final priceColor = bar.accent
        ? NocturneColors.bg.withValues(alpha: 0.7)
        : NocturneColors.neutral300;
    final labelColor = bar.accent
        ? NocturneColors.neutral300
        : NocturneColors.neutral600;
    final fill = bar.accent ? NocturneColors.accent : NocturneColors.neutral800;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: bar.heightPx,
          padding: const EdgeInsets.only(top: 12),
          alignment: Alignment.topCenter,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${bar.value}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bar.price,
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  color: priceColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          bar.label,
          style: TextStyle(
            fontSize: 15,
            decoration: TextDecoration.none,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _OriginBar extends StatelessWidget {
  const _OriginBar({required this.origin});

  final List<_OriginSegment> origin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (var i = 0; i < origin.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                flex: origin[i].share,
                // ColoredBox with no child sizes to `constraints.smallest`
                // — under Row's loose cross-axis constraint that's a
                // height of 0, so the segment would paint nothing without
                // this explicit fill.
                child: SizedBox.expand(child: ColoredBox(color: origin[i].color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OriginLegend extends StatelessWidget {
  const _OriginLegend({required this.origin, required this.kwh});

  final List<_OriginSegment> origin;
  final List<double> kwh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < origin.length; i++) ...[
          if (i > 0) const SizedBox(width: 22),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: origin[i].color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${origin[i].label} ${origin[i].share}% · ${kwh[i].round()} kWh',
            style: TextStyle(
              fontSize: 17,
              decoration: TextDecoration.none,
              color: NocturneColors.neutral400,
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final _Session session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: NocturneColors.text.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: session.color,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text(
              session.date,
              style: TextStyle(
                fontSize: 18,
                decoration: TextDecoration.none,
                color: NocturneColors.neutral300,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              session.kwh,
              style: TextStyle(
                fontSize: 18,
                decoration: TextDecoration.none,
                color: NocturneColors.text,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              session.eur,
              style: TextStyle(
                fontSize: 18,
                decoration: TextDecoration.none,
                color: NocturneColors.text,
              ),
            ),
          ),
          Expanded(
            child: Text(
              session.src,
              style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.none,
                color: NocturneColors.neutral500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
