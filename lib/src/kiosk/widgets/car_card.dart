import 'package:flutter/material.dart';

import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'kiosk_widgets.dart';

/// One car (the design's "Carro" component): name, a state chip, the
/// battery or tank % with range, and a level bar. Electric: the charging
/// state, striped and animated while charging, with the charge-limit
/// marker; red under 20%. Fuel: locked or not; red under 15% (reserve).
class KCarCard extends StatelessWidget {
  const KCarCard({super.key, required this.car, this.background = KColors.sub, this.radius = 24});

  final CarInfo car;

  /// Grey inside a white section (Início), white on its own (Casa).
  final Color background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final b = car.level;
    final fuel = car.isFuel;
    final low = b != null && b < (fuel ? 15 : 20);
    final (chipLabel, chipBg, chipFg, chipIcon) = fuel
        ? switch (car.locked) {
            true => ('Trancado', KColors.greenTint, KColors.greenInk, KIcons.lock),
            false => ('Destrancado', KColors.amberTint, KColors.amberInk, KIcons.lockOpen),
            null => (car.place ?? 'Sem estado', KColors.chipAlt, KColors.ink2, KIcons.car),
          }
        : switch (car.state) {
            EvState.charging => ('A carregar', KColors.green, Colors.white, KIcons.boltFilled),
            EvState.waiting => ('Ligado · à espera de carga', KColors.amberTint, KColors.amberInk, KIcons.clock),
            EvState.unplugged => ('Desligado da ficha', KColors.chipAlt, KColors.ink2, KIcons.unplugged),
            EvState.unknown => ('Sem estado de carga', KColors.chipAlt, KColors.ink2, KIcons.car),
          };
    final updated = car.updated == null ? '' : 'Atualizado às ${PtDates.hm(car.updated!)}';
    final detail = fuel
        ? [?car.place, if (low) 'reserva, abastecer em breve'].join(' · ')
        : switch (car.state) {
            EvState.charging => [if (car.powerKw != null) '${ptDec(car.powerKw!)} kW', if (car.limit != null) 'até ${car.limit!.round()}%'].join(' · '),
            _ => car.place ?? updated,
          };
    final barColor = low
        ? KColors.red
        : fuel
        ? KColors.ink2
        : switch (car.state) {
            EvState.charging => KColors.green,
            EvState.waiting => KColors.amber,
            _ => KColors.muted,
          };
    final caption = fuel ? 'Depósito' : (car.limit == null ? null : 'Limite ${car.limit!.round()}%');
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(18, 18, 24, 18),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: background == Colors.white ? KColors.sub : Colors.white, borderRadius: BorderRadius.circular(22)),
            child: const Center(child: KIcon(KIcons.car, size: 38, stroke: 1.7)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.s(22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 38,
                  padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(19)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KBlink(
                        enabled: !fuel && car.state == EvState.charging,
                        child: KIcon(chipIcon, size: 20, color: chipFg, stroke: 2.2, filled: !fuel && car.state == EvState.charging),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          chipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.s(17, weight: FontWeight.w700, color: chipFg),
                        ),
                      ),
                    ],
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    PtDates.cap(detail),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.s(16, color: KColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 210,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: b == null ? '--' : '${b.round()}',
                        children: [
                          TextSpan(
                            text: '%',
                            style: KText.d(24, color: low ? KColors.red : KColors.ink),
                          ),
                        ],
                      ),
                      style: KText.d(44, color: low ? KColors.red : KColors.ink, height: 1),
                    ),
                    const Spacer(),
                    if (car.rangeKm != null)
                      Text(
                        '${car.rangeKm!.round()} km',
                        style: KText.s(17, weight: FontWeight.w600, color: KColors.ink2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _BatteryBar(
                  value: (b ?? 0) / 100,
                  limit: fuel || car.limit == null ? null : car.limit! / 100,
                  color: barColor,
                  striped: !fuel && car.state == EvState.charging,
                ),
                if (caption != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (fuel) ...[const KIcon(KIcons.fuel, size: 16, color: KColors.muted), const SizedBox(width: 6)],
                      Text(caption, style: KText.s(15, color: KColors.muted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryBar extends StatefulWidget {
  const _BatteryBar({required this.value, required this.limit, required this.color, required this.striped});

  final double value;
  final double? limit;
  final Color color;
  final bool striped;

  @override
  State<_BatteryBar> createState() => _BatteryBarState();
}

class _BatteryBarState extends State<_BatteryBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.striped) _c.repeat();
  }

  @override
  void didUpdateWidget(_BatteryBar old) {
    super.didUpdateWidget(old);
    if (widget.striped && !_c.isAnimating) _c.repeat();
    if (!widget.striped && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: KColors.border, borderRadius: BorderRadius.circular(9)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: kEase,
              // Explicit height: while charging the only child is the stripe
              // painter, which has no size of its own and would collapse
              // the fill to 0 px.
              width: box.maxWidth * widget.value.clamp(0.0, 1.0),
              height: 18,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(9)),
              // Its own layer, repainted straight from the controller: the
              // stripes move every frame, the rest of the page shouldn't
              // have to be redrawn with them.
              child: widget.striped ? RepaintBoundary(child: CustomPaint(painter: _StripePainter(_c))) : null,
            ),
            if (widget.limit != null)
              Positioned(
                left: box.maxWidth * widget.limit!.clamp(0.0, 1.0) - 1.5,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: KColors.ink.withValues(alpha: 0.55)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final paint = Paint()..color = const Color(0x47FFFFFF);
    for (double x = -28 + t * 28; x < size.width + 28; x += 14 * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + 7, size.height)
        ..lineTo(x + 7 + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.clock != clock;
}
