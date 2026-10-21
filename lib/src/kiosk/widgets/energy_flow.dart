import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/individual_sensors_store.dart';
import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';

const _solar = Color(0xFFA06510);
const _battery = Color(0xFF16794A);
const _grid = Color(0xFF2A6BAB);
const _idle = KColors.border;

String _kw(double? v) =>
    v == null ? '--' : '${ptDec(v.abs(), decimals: v.abs() < 1 ? 2 : 1).replaceAll(RegExp(r',?0+$'), '').replaceAll(RegExp(r',$'), '')} kW';

/// The design's energy diagram: grid (left), solar (top), battery
/// (bottom) feeding the house (right), with dots running along whichever
/// connections carry power. [consumers] adds the Casa page's column of
/// individual loads to the right of the house.
class KEnergyFlow extends StatefulWidget {
  const KEnergyFlow({super.key, required this.info, this.consumers = false, this.label = 'ENERGIA', this.labelColor = KColors.accent, this.radius = 22});

  final EnergyInfo info;
  final bool consumers;

  /// The corner label: "ENERGIA" on Início, "AGORA" in Casa's Energia.
  final String label;
  final Color labelColor;
  final double radius;

  @override
  State<KEnergyFlow> createState() => _KEnergyFlowState();
}

class _KEnergyFlowState extends State<KEnergyFlow> with SingleTickerProviderStateMixin {
  // One shared clock; each connection derives its own phase/speed from it.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    final c = widget.consumers;
    final gridX = c ? .125 : .15, midX = c ? .375 : .5, homeX = c ? .625 : .85;
    return Container(
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(widget.radius)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 22,
            child: Text(
              widget.label,
              style: KText.s(
                15,
                weight: widget.labelColor == KColors.accent ? FontWeight.w600 : FontWeight.w700,
                color: widget.labelColor,
                spacing: widget.labelColor == KColors.accent ? 1.5 : 1,
              ),
            ),
          ),
          Positioned.fill(
            top: 30,
            left: 10,
            right: 10,
            bottom: 46,
            child: LayoutBuilder(
              builder: (context, box) {
                Offset at(double x, double y) => Offset(box.maxWidth * x, box.maxHeight * y);
                Widget node(double x, double y, Widget child) => Positioned(
                  left: box.maxWidth * x - 60,
                  top: box.maxHeight * y - 60,
                  width: 120,
                  height: 120,
                  child: Center(child: child),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _FlowPainter(info: i, consumers: c, at: at, gridX: gridX, midX: midX, homeX: homeX, clock: _clock),
                        ),
                      ),
                    ),
                    node(gridX, .5, _gridNode(i)),
                    node(
                      midX,
                      .12,
                      _circleNode(
                        bg: const Color(0xFFEADFCF),
                        icon: KIcons.sun,
                        iconColor: const Color(0xFF8A560C),
                        value: _kw(i.solarKw),
                        valueColor: const Color(0xFF8A560C),
                      ),
                    ),
                    node(midX, .88, _batteryNode(i)),
                    node(homeX, .5, _homeNode(i)),
                    if (c)
                      for (final (k, consumer) in i.consumers.take(4).indexed)
                        Positioned(
                          left: box.maxWidth * (k < 2 ? homeX : .875) - 70,
                          top: box.maxHeight * (k.isEven ? .12 : .88) - 46,
                          width: 140,
                          child: _consumerNode(consumer, top: k.isEven),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleNode({
    required Color bg,
    required String icon,
    required Color iconColor,
    required String value,
    required Color valueColor,
    bool filled = false,
  }) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: KColors.sub, spreadRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KIcon(icon, size: 32, color: iconColor, stroke: 1.6, filled: filled),
          const SizedBox(height: 6),
          Text(
            value,
            style: KText.s(16, weight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _badge(Color color, String icon) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: KColors.sub, spreadRadius: 5)],
    ),
    child: Center(child: KIcon(icon, size: 16, color: Colors.white, stroke: 3)),
  );

  Widget _gridNode(EnergyInfo i) {
    final g = i.gridKw ?? 0;
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _circleNode(
            bg: const Color(0xFFD8E0E6),
            icon: KIcons.pylonFilled,
            iconColor: const Color(0xFF2F7CC4),
            value: _kw(i.gridKw),
            valueColor: const Color(0xFF1F5A93),
            filled: true,
          ),
          if (g != 0) Positioned(top: -2, right: -2, child: _badge(const Color(0xFF2F7CC4), g > 0 ? KIcons.arrowRight : KIcons.arrowLeft)),
        ],
      ),
    );
  }

  Widget _batteryNode(EnergyInfo i) {
    final b = i.batteryKw ?? 0;
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _circleNode(
            bg: const Color(0xFFD5E2D8),
            icon: KIcons.battery,
            iconColor: const Color(0xFF12663E),
            value: _kw(i.batteryKw),
            valueColor: const Color(0xFF12663E),
          ),
          if (b != 0) Positioned(top: -2, right: -2, child: _badge(const Color(0xFF2F9E68), b > 0 ? KIcons.arrowUp : KIcons.arrowDown)),
          if (i.soc != null)
            Positioned(
              bottom: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12663E),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: KColors.sub, spreadRadius: 5)],
                  ),
                  child: Text(
                    '${i.soc!.round()}%',
                    style: KText.s(13, weight: FontWeight.w600, color: Colors.white, height: 1.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _homeNode(EnergyInfo i) {
    final solar = math.max(0.0, i.solarKw ?? 0) - math.max(0.0, -(i.gridKw ?? 0)) - math.max(0.0, -(i.batteryKw ?? 0));
    final shares = [math.max(0.0, solar), math.max(0.0, i.batteryKw ?? 0), math.max(0.0, i.gridKw ?? 0)];
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: KColors.sub,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: KColors.sub, spreadRadius: 8)],
      ),
      child: CustomPaint(
        painter: _HomeRingPainter(shares),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const KIcon(KIcons.home2, size: 28, stroke: 1.8),
              const SizedBox(height: 4),
              Text(_kw(i.homeKw), style: KText.s(16, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consumerNode(EnergyConsumer c, {required bool top}) {
    final icon = switch (c.icon) {
      IndividualSensorIconKey.boiler => KIcons.boiler,
      IndividualSensorIconKey.fridge => KIcons.fridge,
      IndividualSensorIconKey.tv => KIcons.tvSmall,
      IndividualSensorIconKey.washer => KIcons.washer,
      IndividualSensorIconKey.ac => KIcons.snow,
      IndividualSensorIconKey.plug => KIcons.plug,
      IndividualSensorIconKey.oven => KIcons.oven,
    };
    final circle = Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: KColors.sub, spreadRadius: 6)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (c.temp != null) ...[
            Text(
              '${c.temp!.round()}ºC',
              style: KText.s(14, weight: FontWeight.w600, color: KColors.muted, height: 1),
            ),
            const SizedBox(height: 3),
          ],
          KIcon(icon, size: 26, color: KColors.ink2, stroke: 1.7),
          const SizedBox(height: 3),
          Text(_kw(c.kw), style: KText.s(13, weight: FontWeight.w600)),
        ],
      ),
    );
    final label = Text(
      c.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: KText.s(14, color: KColors.muted),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [circle, const SizedBox(height: 4), label]);
  }
}

class _HomeRingPainter extends CustomPainter {
  _HomeRingPainter(this.shares);

  /// solar, battery, grid — kW each.
  final List<double> shares;

  static const _colors = [Color(0xFFC98A2A), Color(0xFF2F9E68), Color(0xFF2F7CC4)];
  static const _tints = [Color(0xFFF5EAD9), Color(0xFFDAEEE4), Color(0xFFDAE7F4)];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 2.5;
    final total = shares.fold<double>(0, (a, b) => a + b);
    final track = Paint()
      ..color = KColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, r, track);
    if (total <= 0) {
      canvas.drawCircle(center, size.width / 2 - 8, Paint()..color = Colors.white);
      return;
    }
    // Inner disc tinted by the same mix (the design's conic gradient).
    var start = -math.pi / 2;
    final inner = Rect.fromCircle(center: center, radius: size.width / 2 - 8);
    for (var k = 0; k < 3; k++) {
      final sweep = shares[k] / total * math.pi * 2;
      if (sweep <= 0) continue;
      canvas.drawArc(inner, start, sweep, true, Paint()..color = _tints[k]);
      start += sweep;
    }
    start = -math.pi / 2 + 0.05;
    final ring = Rect.fromCircle(center: center, radius: r);
    for (var k = 0; k < 3; k++) {
      final sweep = shares[k] / total * math.pi * 2;
      if (sweep <= 0.1) {
        start += sweep;
        continue;
      }
      canvas.drawArc(
        ring,
        start,
        sweep - 0.1,
        false,
        Paint()
          ..color = _colors[k]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_HomeRingPainter old) => old.shares.join() != shares.join();
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.info,
    required this.consumers,
    required this.at,
    required this.gridX,
    required this.midX,
    required this.homeX,
    required this.clock,
  }) : super(repaint: clock);

  final EnergyInfo info;
  final bool consumers;
  final Offset Function(double x, double y) at;
  final double gridX, midX, homeX;
  final Animation<double> clock;

  Path _curve(Offset a, Offset ctrl, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

  Path _line(Offset a, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = at(gridX, .5), solar = at(midX, .12), battery = at(midX, .88), home = at(homeX, .5);
    final dx = (midX - gridX) * .05;
    final solarGrid = _curve(solar, at(midX - dx, .481), grid);
    final gridBattery = _curve(grid, at(midX - dx, .519), battery);
    final solarBattery = _line(solar, battery);
    final solarHome = _curve(solar, at(midX + dx, .481), home);
    final batteryHome = _curve(battery, at(midX + dx, .519), home);
    final gridHome = _line(grid, home);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _idle;
    for (final p in [solarGrid, gridBattery, solarBattery, solarHome, batteryHome, gridHome]) {
      canvas.drawPath(p, base);
    }

    final flows = <(Path, Color, double, bool)>[];
    final s = info.solarKw ?? 0, g = info.gridKw ?? 0, b = info.batteryKw ?? 0;
    if (s > 0) flows.add((solarHome, _solar, 2.4, false));
    if (b > 0) flows.add((batteryHome, _battery, 2.8, false));
    if (b < 0) flows.add((s > 0 ? solarBattery : gridBattery, _battery, 2.8, false));
    if (g > 0) flows.add((gridHome, _grid, 3.0, false));
    if (g < 0) flows.add((s > 0 ? solarGrid : gridHome, _grid, 3.0, s <= 0));

    if (consumers) {
      final top = at(.875, .12), bottom = at(.875, .88), homeTop = at(homeX, .12), homeBottom = at(homeX, .88);
      final links = [_line(home, homeTop), _line(home, homeBottom), _curve(home, at(.875 - .0125, .481), top), _curve(home, at(.875 - .0125, .519), bottom)];
      for (final (k, p) in links.indexed) {
        canvas.drawPath(p, base);
        if (k < info.consumers.length && (info.consumers[k].kw ?? 0) > 0) flows.add((p, KColors.faint2, 3.4 + k * .2, false));
      }
    }

    for (final (path, color, secs, reverse) in flows) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
      final metric = path.computeMetrics().firstOrNull;
      if (metric == null) continue;
      final t = (clock.value * 12 / secs) % 1.0;
      final pos = metric.getTangentForOffset(metric.length * (reverse ? 1 - t : t))?.position;
      if (pos != null) canvas.drawCircle(pos, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
