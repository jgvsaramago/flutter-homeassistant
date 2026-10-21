import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/weekly_forecast_provider.dart';
import '../data/casa_data.dart';
import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> showEnergyModal(BuildContext context) => showKModal(context, (_) => const EnergyModal());

const _sun = Color(0xFFC98A2A);
const _sunInk = Color(0xFF8A560C);
const _use = Color(0xFF9AA0A6);
const _export = Color(0xFF2F7CC4);
const _battery = Color(0xFF2F9E68);
const _batteryInk = Color(0xFF12663E);

String _eur(double v) => '${ptDec(v, decimals: 2)} €';

/// Casa › Energia › "Ver mais": today's totals, hour by hour against the
/// solar forecast, the next days' forecast, battery and grid, what's
/// drawing power now and the last 7 days — HA's Energy dashboard data.
class EnergyModal extends ConsumerWidget {
  const EnergyModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(energyStatsProvider).valueOrNull;
    final now = ref.watch(energyInfoProvider);
    final tariff = ref.watch(tariffNowProvider);
    final days = ref.watch(weeklyForecastProvider).valueOrNull ?? const <WeeklyForecastDay>[];
    final today = DateTime.now();
    final t = stats?.today;

    Widget h3(String text, {Widget? trailing}) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(text, style: KText.cardTitle)),
        ?trailing,
      ],
    );
    Widget legend(List<(Widget, String)> items) => Row(
      children: [
        for (final (i, (mark, label)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 18),
          mark,
          const SizedBox(width: 8),
          Text(label, style: KText.s(17, color: KColors.muted)),
        ],
      ],
    );
    Widget box(Color c, {double w = 12, double h = 14}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
    );
    Widget card({required Widget child, EdgeInsets padding = const EdgeInsets.all(22)}) => Container(
      padding: padding,
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(22)),
      child: child,
    );
    Widget kv(String k, String v) => Row(
      children: [
        Expanded(
          child: Text(k, style: KText.s(18, color: KColors.muted)),
        ),
        Text(v, style: KText.s(18, weight: FontWeight.w600)),
      ],
    );

    final forecastToday = stats?.forecastFor(today);
    final savings = t == null ? null : stats!.savings(t);
    final kpis = [
      ('SOLAR HOJE', t == null ? '--' : ptKwh(t.solar), 'kWh', forecastToday == null ? '' : 'De ${ptKwh(forecastToday)} kWh previstos', _sunInk),
      (
        'CONSUMO',
        t == null ? '--' : ptKwh(t.consumption),
        'kWh',
        stats?.yesterdaySoFar == null ? '' : 'Ontem a esta hora: ${ptKwh(stats!.yesterdaySoFar!.consumption)}',
        KColors.ink,
      ),
      ('AUTOCONSUMO', t?.selfUse == null ? '--' : '${(t!.selfUse! * 100).round()}', '%', 'Veio do sol ou da bateria', _batteryInk),
      ('POUPANÇA', savings == null ? '--' : ptDec(savings, decimals: 2), '€', 'Hoje, face a só rede', KColors.ink),
    ];

    final batteryUntil = batteryLastsUntil(now, stats);
    final sunAt = solarCoversHomeAt(now, stats);
    final bat = now.batteryKw;
    final batteryRows = [
      if (bat != null) ('Agora', bat > 0.05 ? 'A fornecer ${ptKw(bat)}' : (bat < -0.05 ? 'A carregar ${ptKw(bat)}' : 'Em repouso')),
      if (batteryUntil != null) ('Ao ritmo atual dura até', PtDates.hm(batteryUntil)),
      if (bat != null && bat > 0.05 && sunAt != null) ('Volta a carregar (previsão)', '≈ ${PtDates.hm(sunAt)}, com o sol'),
      if (stats?.capacity != null) ('Capacidade', '${ptKwh(stats!.capacity!)} kWh'),
    ];
    final grid = now.gridKw;
    final (gridLabel, gridBg, gridFg) = grid == null || grid.abs() < 0.05
        ? ('Sem trocas', KColors.chipAlt, KColors.ink2)
        : grid > 0
        ? ('A importar ${ptKw(grid)}', const Color(0xFFDAE7F4), const Color(0xFF1F5A93))
        : ('A vender ${ptKw(grid)}', KColors.greenTint, KColors.greenInk);
    final importCost = t == null ? null : (t.cost ?? (stats!.price == null ? null : t.gridIn * stats.price!));
    final gridRows = [
      if (t != null) ('Importado hoje', '${ptKwh(t.gridIn)} kWh${importCost == null ? '' : ' · ${_eur(importCost)}'}'),
      if (t != null) ('Vendido hoje', '${ptKwh(t.gridOut)} kWh'),
      if (tariff != null) ('Tarifa agora', tariff),
      if (stats?.price != null) ('Preço agora', '${ptDec(stats!.price!, decimals: 3)} €/kWh'),
    ];

    const loadColors = [KColors.orange, KColors.blue, _battery, KColors.purple];
    final loads = [
      for (final (i, c) in now.consumers.indexed)
        if (c.kw != null) (c.name, c.kw!, loadColors[i % loadColors.length]),
    ];
    if (now.homeKw != null) {
      final rest = now.homeKw! - loads.fold<double>(0, (a, l) => a + l.$2);
      if (rest > 0.01) loads.add(('Outros', rest, _use));
    }
    final loadMax = loads.fold<double>(0.01, (a, l) => math.max(a, l.$2));

    final week = stats?.week ?? const [];
    final weekMax = week.fold<double>(1, (a, d) => math.max(a, math.max(d.amounts.solar, math.max(d.amounts.consumption, d.amounts.gridOut))));
    final weekTotal = week.fold(const EnergyAmounts(), (a, d) => a + d.amounts);
    final weekSavings = stats?.savings(weekTotal);

    final forecast = [
      for (var i = 0; i < 6; i++)
        if (stats?.forecastFor(addDays(today, i)) case final kwh?)
          (i == 0 ? 'Hoje' : (i == 1 ? 'Amanhã' : PtDates.abbrTitle[addDays(today, i).weekday - 1]), kwh, i < days.length ? days[i].condition : null, i == 1),
    ];
    final fcMax = forecast.fold<double>(1, (a, f) => math.max(a, f.$2));

    final sections = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (label, value, unit, sub, color)) in kpis.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: card(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: KText.label),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: value,
                        children: [
                          TextSpan(
                            text: ' $unit',
                            style: KText.s(18, weight: FontWeight.w600, color: KColors.muted),
                          ),
                        ],
                      ),
                      style: KText.d(36, color: color, height: 1.05),
                    ),
                    const SizedBox(height: 6),
                    Text(sub, style: KText.s(15, color: KColors.muted, height: 1.35)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      if (stats != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            h3(
              'Hoje, hora a hora',
              trailing: legend([
                (box(_sun, w: 18, h: 4), 'Solar'),
                if (stats.forecastSlots.isNotEmpty) (const SizedBox(width: 18, height: 4, child: CustomPaint(painter: _DashPainter(_sun))), 'Previsão'),
                (box(_use), 'Consumo'),
              ]),
            ),
            const SizedBox(height: 14),
            SizedBox(height: 300, child: _TodayChart(stats: stats)),
          ],
        ),
      if (forecast.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            h3('Previsão solar'),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (day, kwh, condition, tomorrow)) in forecast.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      decoration: BoxDecoration(color: tomorrow ? const Color(0xFFFFF4E0) : KColors.sub, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(day, maxLines: 1, style: KText.s(20, weight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              KIcon(weatherIcon(condition), size: 28, color: _sun, stroke: 1.8),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 90,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (kwh / fcMax).clamp(0.04, 1.0),
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9B35A), _sun]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              text: ptKwh(kwh),
                              children: [
                                TextSpan(
                                  text: ' kWh',
                                  style: KText.s(15, weight: FontWeight.w600, color: KColors.muted),
                                ),
                              ],
                            ),
                            style: KText.d(28),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 39,
                            child: Text(weatherLabel(condition), maxLines: 2, style: KText.s(15, color: KColors.muted, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      if (now.soc != null || grid != null)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (now.soc != null)
                Expanded(
                  child: card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Bateria', style: KText.s(24, weight: FontWeight.w600)),
                            ),
                            Text('${now.soc!.round()}%', style: KText.d(34, color: _batteryInk)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        KProgress(value: now.soc! / 100, height: 16, track: const Color(0xFFDCE8DF), fill: _battery),
                        for (final (k, v) in batteryRows) ...[const SizedBox(height: 14), kv(k, v)],
                      ],
                    ),
                  ),
                ),
              if (now.soc != null && grid != null) const SizedBox(width: 12),
              if (grid != null)
                Expanded(
                  child: card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Rede', style: KText.s(24, weight: FontWeight.w600)),
                            ),
                            Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: gridBg, borderRadius: BorderRadius.circular(18)),
                              child: Text(
                                gridLabel,
                                style: KText.s(16, weight: FontWeight.w700, color: gridFg),
                              ),
                            ),
                          ],
                        ),
                        for (final (k, v) in gridRows) ...[const SizedBox(height: 14), kv(k, v)],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (loads.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            h3(
              'Consumo agora',
              trailing: now.homeKw == null ? null : Text(ptKw(now.homeKw!), style: KText.s(20, weight: FontWeight.w600)),
            ),
            const SizedBox(height: 14),
            for (final (i, (name, kw, color)) in loads.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KProgress(value: kw / loadMax, height: 14, track: KColors.chip, fill: color),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    child: Text(
                      ptKw(kw),
                      textAlign: TextAlign.right,
                      style: KText.s(20, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      if (week.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            h3('Últimos 7 dias', trailing: legend([(box(_sun), 'Produzido'), (box(_use), 'Consumido'), (box(_export), 'Exportado')])),
            const SizedBox(height: 14),
            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(22)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, d) in week.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: i == week.length - 1 ? 0.5 : 1,
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final (j, (v, c)) in [(d.amounts.solar, _sun), (d.amounts.consumption, _use), (d.amounts.gridOut, _export)].indexed) ...[
                                    if (j > 0) const SizedBox(width: 3),
                                    FractionallySizedBox(
                                      heightFactor: (v / weekMax).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 22,
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                PtDates.abbrTitle[d.day.weekday - 1],
                                style: KText.s(15, weight: FontWeight.w600, color: KColors.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Últimos 7 dias: ${ptKwh(weekTotal.solar)} kWh produzidos, ${ptKwh(weekTotal.consumption)} kWh consumidos, ${ptKwh(weekTotal.gridOut)} kWh exportados'
              '${weekSavings == null ? '' : ' · poupança estimada ${_eur(weekSavings)}'}.',
              style: KText.s(17, color: KColors.muted),
            ),
          ],
        ),
      if (stats == null)
        Text(
          'Os totais, a previsão e o histórico vêm do painel Energia do Home Assistant, que não está configurado.',
          style: KText.s(20, color: KColors.muted),
        ),
    ];

    return KModal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KModalHeader(title: 'Energia', subtitle: 'Hoje, ${PtDates.longLower(today)}${stats == null ? '' : ' · atualizado às ${PtDates.hm(stats.updated)}'}'),
          for (final s in sections) ...[const SizedBox(height: 28), s],
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: KColors.divider, width: 1.5)),
            ),
            alignment: Alignment.centerRight,
            child: KButton.primary(
              label: 'Concluído',
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 44),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3;
    final y = size.height / 2;
    canvas.drawPoints(PointMode.lines, [
      for (double x = 0; x < size.width; x += 8) ...[Offset(x, y), Offset(math.min(x + 4, size.width), y)],
    ], p);
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Today's chart: consumption per hour as grey bars, the solar production
/// so far as a filled line, the forecast for the rest of the day dashed,
/// and a "now" marker.
class _TodayChart extends StatelessWidget {
  const _TodayChart({required this.stats});

  final EnergyStats stats;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60;
    final hours = stats.hours;
    // The current hour is partial: scale its kWh to an hourly rate.
    double rate(int h, double kwh) => h == hours.length - 1 ? kwh / math.max(now.minute / 60, 1 / 12) : kwh;
    final use = [for (final (h, a) in hours.indexed) rate(h, a.consumption)];
    final solar = [for (final (h, a) in hours.indexed) rate(h, a.solar)];
    final peak = stats.forecastPeak;
    final top = [...use, ...solar, ...stats.forecastSlots.map((s) => s.kw), 1.0].reduce(math.max);
    final maxKw = (top * 1.1).ceilToDouble();
    const padL = 56.0, padR = 20.0, padT = 20.0, padB = 40.0;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth - padL - padR, h = box.maxHeight - padT - padB;
        double x(double hour) => padL + hour / 24 * w;
        double y(double kw) => padT + h - kw / maxKw * h;
        return Container(
          decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(22)),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChartPainter(use: use, solar: solar, forecast: stats.forecastSlots, nowH: nowH, maxKw: maxKw, x: x, y: y, bottom: padT + h),
                ),
              ),
              for (var k = 0; k <= maxKw; k += maxKw > 6 ? 2 : 1)
                Positioned(
                  left: 12,
                  top: y(k.toDouble()) - 9,
                  child: Text('$k kW', style: KText.s(14, color: KColors.muted)),
                ),
              for (final hr in const [0, 6, 12, 18, 24])
                Positioned(
                  left: x(hr.toDouble()) - 22,
                  width: 44,
                  bottom: 10,
                  child: Text(
                    '${PtDates.two(hr)}:00',
                    textAlign: TextAlign.center,
                    style: KText.s(14, color: KColors.muted),
                  ),
                ),
              Positioned(
                left: x(nowH) - 32,
                width: 64,
                top: 8,
                child: Center(
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: KColors.dark, borderRadius: BorderRadius.circular(13)),
                    child: Text(
                      'Agora',
                      style: KText.s(14, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (peak != null && peak.at.isAfter(now))
                Positioned(
                  left: x(peak.at.hour + peak.at.minute / 60) - 140,
                  width: 280,
                  top: 40,
                  child: Text(
                    'Pico previsto ${ptKw(peak.kw)} · ${PtDates.hm(peak.at)}',
                    textAlign: TextAlign.center,
                    style: KText.s(15, weight: FontWeight.w600, color: _sunInk),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.use,
    required this.solar,
    required this.forecast,
    required this.nowH,
    required this.maxKw,
    required this.x,
    required this.y,
    required this.bottom,
  });

  final List<double> use;
  final List<double> solar;
  final List<({DateTime at, double kw})> forecast;
  final double nowH;
  final double maxKw;
  final double Function(double) x;
  final double Function(double) y;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = KColors.border
      ..strokeWidth = 1;
    for (var k = 1; k <= maxKw; k += maxKw > 6 ? 2 : 1) {
      canvas.drawLine(Offset(x(0), y(k.toDouble())), Offset(x(24), y(k.toDouble())), grid);
    }
    final bars = Paint()..color = _use.withValues(alpha: 0.75);
    final slot = x(1) - x(0);
    for (final (h, kw) in use.indexed) {
      if (kw <= 0) continue;
      final w = h == use.length - 1 ? slot * 0.42 : slot * 0.6;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          x(h.toDouble()) + slot * 0.2,
          y(kw),
          x(h.toDouble()) + slot * 0.2 + w,
          bottom,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        bars,
      );
    }

    void curve(List<Offset> pts, {required double fillAlpha, required bool dashed, required double width}) {
      if (pts.length < 2) return;
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      final area = Path.from(line)
        ..lineTo(pts.last.dx, bottom)
        ..lineTo(pts.first.dx, bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = _sun.withValues(alpha: fillAlpha));
      final stroke = Paint()
        ..color = _sun
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round;
      if (!dashed) {
        canvas.drawPath(line, stroke);
        return;
      }
      for (final m in line.computeMetrics()) {
        for (double d = 0; d < m.length; d += 12) {
          canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), stroke);
        }
      }
    }

    // Production so far: each hour's average at its middle, from midnight.
    curve([Offset(x(0), y(0)), for (final (h, kw) in solar.indexed) Offset(x(math.min(h + 0.5, nowH)), y(kw))], fillAlpha: 0.28, dashed: false, width: 3);
    final ahead = [
      for (final s in forecast)
        if (s.at.hour + s.at.minute / 60 >= nowH - 0.5) Offset(x(s.at.hour + s.at.minute / 60), y(s.kw)),
    ];
    curve(ahead, fillAlpha: 0.10, dashed: true, width: 2.5);

    final nowPaint = Paint()
      ..color = KColors.ink
      ..strokeWidth = 1.5;
    for (double d = 0; d < bottom; d += 7) {
      canvas.drawLine(Offset(x(nowH), d), Offset(x(nowH), math.min(d + 3, bottom)), nowPaint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
