import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'kiosk_widgets.dart';

String acModeIcon(AcMode m) => switch (m) {
  AcMode.heat => KIcons.flame,
  AcMode.cool => KIcons.snow,
  AcMode.fan || AcMode.auto => KIcons.fan,
};

/// Holds a target temperature locally while the −/+ buttons are being
/// tapped and sends it once they settle, so quick taps don't each race a
/// round trip to HA (and the AC beeping for every half degree).
mixin _DebouncedTarget<T extends StatefulWidget> on State<T> {
  double? pending;
  Timer? _timer;

  void bump(double from, double delta, double min, double max, Future<void> Function(double) send) {
    final next = ((pending ?? from) + delta).clamp(min, max).toDouble();
    setState(() => pending = next);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () async {
      try {
        await send(next);
      } catch (e) {
        KToast.error(e);
        if (mounted) setState(() => pending = null);
        return;
      }
      // Keep showing the sent value until HA echoes it back (or give up).
      _timer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => pending = null);
      });
    });
  }

  void settleIfEchoed(double? actual) {
    if (pending != null && actual != null && (actual - pending!).abs() < 0.01 && !(_timer?.isActive ?? false)) pending = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// One AC unit as a control row: power badge (showing the mode), name and
/// current temperature, −/+ target stepper and, while on, the mode chips.
class KAcRow extends ConsumerStatefulWidget {
  const KAcRow({super.key, required this.unit});

  final AcUnit unit;

  @override
  ConsumerState<KAcRow> createState() => _KAcRowState();
}

class _KAcRowState extends ConsumerState<KAcRow> with _DebouncedTarget {
  @override
  void didUpdateWidget(KAcRow old) {
    super.didUpdateWidget(old);
    settleIfEchoed(widget.unit.target);
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    final actions = ref.read(acActionsProvider);
    final target = pending ?? u.target;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: u.on ? Colors.white : const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Row(
            children: [
              KPress(
                onTap: () => _run(() => actions.power(u, !u.on)),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: u.on ? u.mode.tint : KColors.chipAlt, borderRadius: BorderRadius.circular(18)),
                  child: Center(child: KIcon(u.on ? acModeIcon(u.mode) : KIcons.power, size: 28, color: u.on ? u.mode.color : KColors.faint, stroke: 2)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.s(20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text('Agora ${ptDeg(u.current)}${u.on ? ' · ${u.mode.label}' : ''}', style: KText.s(16, color: KColors.muted)),
                  ],
                ),
              ),
              if (u.on)
                Row(
                  children: [
                    KStepButton(plus: false, size: 52, onTap: () => bump(u.target ?? 21, -u.step, u.min, u.max, (t) => actions.target(u, t))),
                    SizedBox(
                      width: 80,
                      child: Text(
                        ptDeg(target),
                        textAlign: TextAlign.center,
                        style: KText.d(28, color: u.mode.color),
                      ),
                    ),
                    KStepButton(plus: true, size: 52, onTap: () => bump(u.target ?? 21, u.step, u.min, u.max, (t) => actions.target(u, t))),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Desligado',
                    style: KText.s(17, weight: FontWeight.w600, color: KColors.faint),
                  ),
                ),
            ],
          ),
          if (u.on && u.modes.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 70, top: 10),
              child: Row(
                children: [
                  for (final m in u.modes) ...[
                    KChip(
                      label: m.label,
                      on: u.mode == m,
                      height: 48,
                      fontSize: 16,
                      padX: 16,
                      onBg: m.color,
                      onTap: u.mode == m ? null : () => _run(() => actions.mode(u, m)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A room's AC in its modal (the design's "Modal de uma divisão"): the
/// power badge, "Ar condicionado" with its mode and the room's
/// temperature, the −/+ target — or "Ligar" while off — and the modes.
class KRoomAcBlock extends ConsumerStatefulWidget {
  const KRoomAcBlock({super.key, required this.unit});

  final AcUnit unit;

  @override
  ConsumerState<KRoomAcBlock> createState() => _KRoomAcBlockState();
}

class _KRoomAcBlockState extends ConsumerState<KRoomAcBlock> with _DebouncedTarget {
  @override
  void didUpdateWidget(KRoomAcBlock old) {
    super.didUpdateWidget(old);
    settleIfEchoed(widget.unit.target);
  }

  void _run(Future<void> Function() f) => f().catchError(KToast.error);

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    final actions = ref.read(acActionsProvider);
    final target = pending ?? u.target;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KCircleButton(
                icon: u.on ? acModeIcon(u.mode) : KIcons.power,
                size: 56,
                iconSize: 28,
                bg: u.on ? u.mode.tint : KColors.chipAlt,
                fg: u.on ? u.mode.color : KColors.muted,
                border: null,
                onTap: () => _run(() => actions.power(u, !u.on)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ar condicionado', style: KText.s(24, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${u.on ? u.mode.label : 'Desligado'} · agora ${ptDeg(u.current)}', style: KText.s(17, color: KColors.muted)),
                  ],
                ),
              ),
              if (u.on) ...[
                KStepButton(plus: false, size: 64, onTap: () => bump(u.target ?? 21, -u.step, u.min, u.max, (t) => actions.target(u, t))),
                SizedBox(
                  width: 96,
                  child: Text(
                    ptDeg(target),
                    textAlign: TextAlign.center,
                    style: KText.d(34, color: u.mode.color),
                  ),
                ),
                KStepButton(plus: true, size: 64, onTap: () => bump(u.target ?? 21, u.step, u.min, u.max, (t) => actions.target(u, t))),
              ] else
                KButton.primary(
                  label: 'Ligar',
                  height: 56,
                  fontSize: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  onTap: () => _run(() => actions.power(u, true)),
                ),
            ],
          ),
          if (u.on && u.modes.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final m in u.modes) ...[
                  KChip(
                    label: m.label,
                    on: u.mode == m,
                    height: 56,
                    fontSize: 20,
                    padX: 22,
                    offBg: Colors.white,
                    onBg: m.color,
                    onTap: u.mode == m ? null : () => _run(() => actions.mode(u, m)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Início's "Ar Condicionado" tile: one thermostat for the whole group —
/// the ring shows the average target across the units that are on, the
/// centre button switches them all, −/+ shifts every running unit.
class KAcSummaryCard extends ConsumerStatefulWidget {
  const KAcSummaryCard({super.key, required this.units, required this.onSeeAll});

  final List<AcUnit> units;
  final VoidCallback onSeeAll;

  @override
  ConsumerState<KAcSummaryCard> createState() => _KAcSummaryCardState();
}

class _KAcSummaryCardState extends ConsumerState<KAcSummaryCard> with _DebouncedTarget {
  double? get _avgTarget {
    final on = widget.units.where((u) => u.on && u.target != null).toList();
    if (on.isEmpty) return null;
    return (on.fold<double>(0, (a, u) => a + u.target!) / on.length * 2).round() / 2;
  }

  @override
  void didUpdateWidget(KAcSummaryCard old) {
    super.didUpdateWidget(old);
    settleIfEchoed(_avgTarget);
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.units;
    final on = units.where((u) => u.on).toList();
    final actions = ref.read(acActionsProvider);
    final currents = units.map((u) => u.current).whereType<double>().toList();
    final avgCurrent = currents.isEmpty ? null : currents.reduce((a, b) => a + b) / currents.length;
    final avg = pending ?? _avgTarget;
    final anyOn = on.isNotEmpty;
    final mode = anyOn ? on.first.mode : null;
    final modeLabel = !anyOn
        ? 'Desligado'
        : switch (mode!) {
            AcMode.heat => 'A aquecer',
            AcMode.cool => 'A arrefecer',
            AcMode.fan => 'A ventilar',
            AcMode.auto => 'Automático',
          };
    final modeColor = anyOn ? mode!.color : KColors.muted;

    Future<void> shiftAll(double target) => Future.wait([for (final u in on) actions.target(u, target)]);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Ar Condicionado', style: KText.s(22, weight: FontWeight.w600)),
              ),
              KButton(
                label: 'Ver todos',
                icon: KIcons.chevronRight,
                iconAfter: true,
                iconSize: 18,
                gap: 4,
                height: 44,
                fontSize: 16,
                border: null,
                padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                onTap: widget.onSeeAll,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                KPress(
                  onTap: units.isEmpty
                      ? null
                      : () async {
                          try {
                            if (anyOn) {
                              await actions.allOff(units);
                            } else {
                              await Future.wait([for (final u in units) actions.power(u, true)]);
                            }
                          } catch (e) {
                            KToast.error(e);
                          }
                        },
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _RingPainter(
                        fraction: avg == null ? 0 : ((avg - 16) / 14).clamp(0.0, 1.0),
                        color: anyOn ? const Color(0xFFE8833A) : KColors.ring,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(anyOn ? ptDeg(avg) : 'Off', style: KText.d(anyOn ? 24 : 22, height: 1)),
                            Text(
                              anyOn ? 'ALVO' : 'LIGAR',
                              style: KText.s(12, weight: FontWeight.w700, color: KColors.muted, spacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            modeLabel,
                            style: KText.s(18, weight: FontWeight.w600, color: modeColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Casa ${ptDeg(avgCurrent)}', style: KText.s(16, color: KColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                        units.isEmpty ? 'Sem unidades' : (anyOn ? '${on.length} de ${units.length} ligados' : 'Todos desligados'),
                        style: KText.s(16, color: KColors.muted),
                      ),
                    ],
                  ),
                ),
                if (anyOn)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      KStepButton(plus: true, size: 44, onTap: () => bump(_avgTarget ?? 21, 0.5, 16, 30, shiftAll)),
                      const SizedBox(height: 8),
                      KStepButton(plus: false, size: 44, onTap: () => bump(_avgTarget ?? 21, -0.5, 16, 30, shiftAll)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.42;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    canvas.drawArc(rect, start, sweep, false, paint..color = KColors.border);
    if (fraction > 0) canvas.drawArc(rect, start, sweep * fraction, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
