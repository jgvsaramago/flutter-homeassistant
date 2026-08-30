import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/energy_entities_provider.dart';
import '../../providers/ha_providers.dart';
import '../../providers/individual_sensors_provider.dart';
import '../../providers/individual_sensors_store.dart';
import '../../services/screen_power_controller.dart';
import '../../theme/nocturne_theme.dart';
import '../grid_tower_icon.dart';
import '../individual_sensor_icon.dart';

// Node grid: 4 columns (12.5/37.5/62.5/87.5%) x 3 rows (12/50/88%).
const _gridPos = Offset(0.125, 0.5);
const _solarPos = Offset(0.375, 0.12);
const _batteryPos = Offset(0.375, 0.88);
const _homePos = Offset(0.625, 0.5);

/// The card's 4 fixed "individual sensor" device slots — column A then
/// column B, top then bottom. A configured [IndividualSensorConfig] list
/// (Settings → Cartão de Energia) fills these in order; fewer than 4
/// configured just leaves the remaining slots empty.
const _individualSensorSlots = [
  Offset(0.625, 0.12), // column A, top
  Offset(0.625, 0.88), // column A, bottom
  Offset(0.875, 0.12), // column B, top
  Offset(0.875, 0.88), // column B, bottom
];

const _sourceDiameter = 100.0;
const _homeDiameter = 100.0;
const _applianceDiameter = 92.0;
const _individualSensorZeroThresholdW = 5.0;

String _formatKw(double? kw) {
  if (kw == null) return '--';
  final watts = kw * 1000;
  return watts.abs() >= 1000 ? '${kw.toStringAsFixed(1)} kW' : '${watts.round()} W';
}

/// A configured sensor's stored temperature (or any other °C reading) —
/// null when unconfigured/unavailable/non-numeric, same convention as every
/// other entity reader on this card. `º` (U+00BA) matches the design
/// reference's own glyph, not the degree sign.
String? _readTemperature(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  final value = double.tryParse(entity.state);
  if (value == null) return null;
  return '${value.round()}ºC';
}

/// Reads a configured power sensor as kW, auto-detecting W vs kW from the
/// entity's own `unit_of_measurement` rather than assuming — a sensor
/// configured with the wrong assumed unit would otherwise be silently
/// wrong by 1000x. Readings within [zeroThresholdW] of zero snap to exactly
/// 0 — real power sensors rarely settle on an exact zero, so without this a
/// few watts of standby draw or measurement noise would read as a
/// persistent trickle of import/export forever.
double? _readPowerKw(Map<String, HaEntity> entities, String? entityId, double zeroThresholdW) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  final raw = double.tryParse(entity.state);
  if (raw == null) return null;
  final kw = entity.unitOfMeasurement?.toLowerCase() == 'kw' ? raw : raw / 1000;
  return kw.abs() * 1000 < zeroThresholdW ? 0.0 : kw;
}

double? _readPercent(Map<String, HaEntity> entities, String? entityId) {
  if (entityId == null || entityId.trim().isEmpty) return null;
  final entity = entities[entityId];
  if (entity == null || entity.isUnavailable) return null;
  return double.tryParse(entity.state);
}

/// Section 7 of the Homepage: the "Energia" energy-flow card. Built to a
/// pixel-exact build spec (frame, tokens, node grid, connections all given
/// literally) — see the commit this landed in for the full prompt. Reads
/// grid/solar/battery/home power from user-configured HA entities (see
/// Settings → "Entidades de energia"; this design has no household-specific
/// entity ids baked in, unlike the rest of the dashboard).
class EnergyFlowCard extends ConsumerStatefulWidget {
  const EnergyFlowCard({super.key});

  @override
  ConsumerState<EnergyFlowCard> createState() => _EnergyFlowCardState();
}

class _EnergyFlowCardState extends ConsumerState<EnergyFlowCard> {
  // A vsync-driven AnimationController ticks every frame regardless of its
  // `duration` (duration only sets how fast value sweeps 0→1) — 60Hz
  // forever for dots that only need to look like they're ambiently
  // drifting. A Timer at a much lower rate is a fraction of the CPU cost;
  // see this card's git history for the full reasoning (this was a real,
  // measured CPU problem once). 20fps (the original rate here) turned out
  // to read as visibly choppy though, so this now runs at ~33fps — still
  // roughly half the cost of a 60Hz ticker.
  static const _tickInterval = Duration(milliseconds: 30);

  // Total elapsed milliseconds since ticking started, *not* wrapped to any
  // fixed cycle — each flow derives its own loop position by taking this
  // modulo its own [_flowRate] duration (see _MeshPainter._phase). An
  // earlier version normalized this to a shared 0..1 "master progress" that
  // wrapped every 3s, which corrupted any flow whose own duration was
  // *longer* than 3s (i.e. whenever the receiving node's load was low,
  // pushing its rate toward the slow end near 6s): the master progress
  // would wrap and reset that flow's phase back to 0 before it ever reached
  // 1.0, so the dot visibly snapped back partway along its path instead of
  // reaching the far end. Tracking true elapsed time sidesteps that
  // entirely — there's no cycle length to exceed.
  final _elapsedMs = ValueNotifier<double>(0);
  final _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ScreenPowerController.instance.isOn.addListener(_onScreenPowerChanged);
    if (ScreenPowerController.instance.isOn.value) _startTicking();
  }

  // The screen-off overlay in ScreenPowerGuard sits on top of this card, not
  // in place of it, so without this the mesh would keep repainting 20x/sec
  // under an opaque black box for as long as the screen stays off — pure
  // wasted CPU (this was the app's single biggest idle CPU cost, measured).
  void _onScreenPowerChanged() {
    if (ScreenPowerController.instance.isOn.value) {
      _startTicking();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTicking() {
    if (_timer != null) return;
    _stopwatch
      ..reset()
      ..start();
    var lastElapsedMs = 0;
    _timer = Timer.periodic(_tickInterval, (_) {
      final elapsedMs = _stopwatch.elapsedMilliseconds;
      final deltaMs = elapsedMs - lastElapsedMs;
      lastElapsedMs = elapsedMs;
      _elapsedMs.value += deltaMs;
    });
  }

  @override
  void dispose() {
    ScreenPowerController.instance.isOn.removeListener(_onScreenPowerChanged);
    _timer?.cancel();
    _stopwatch.stop();
    _elapsedMs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(energyEntityConfigProvider);
    final sensors = ref.watch(individualSensorsProvider);
    // Selecting the derived kW/SoC readings (not the raw entity map) means
    // this card only rebuilds when one of its configured sensors actually
    // changes, not on every unrelated entity update flushed from
    // `entitiesProvider`. `sensors` is captured from the outer watch above
    // (not passed into select itself) so this closure is rebuilt — and thus
    // stays in sync — whenever the individual-sensor list changes too.
    final readings = ref.watch(
      entitiesProvider.select((async) {
        final entities = async.value ?? const {};
        return (
          gridKw: _readPowerKw(entities, config.gridPowerEntityId, config.gridZeroThresholdW),
          solarKw: _readPowerKw(entities, config.solarPowerEntityId, config.solarZeroThresholdW),
          batteryKw: _readPowerKw(entities, config.batteryPowerEntityId, config.batteryZeroThresholdW),
          batterySoc: _readPercent(entities, config.batterySocEntityId),
          homeKw: _readPowerKw(entities, config.homePowerEntityId, config.homeZeroThresholdW),
          sensors: [
            for (final s in sensors.take(_individualSensorSlots.length))
              (
                kw: _readPowerKw(entities, s.powerEntityId, _individualSensorZeroThresholdW),
                temperature: _readTemperature(entities, s.temperatureEntityId),
              ),
          ],
        );
      }),
    );
    final gridKw = readings.gridKw;
    final solarKw = readings.solarKw;
    final batteryKw = readings.batteryKw;
    final batterySoc = readings.batterySoc;
    final homeKw = readings.homeKw;
    final sensorReadings = readings.sensors;

    // Comparing against 0 rather than a small epsilon here is deliberate:
    // _readPowerKw already snapped anything under the configured threshold
    // to exactly 0.0, so that's the one place "is this basically zero" is
    // decided — duplicating a second, hardcoded cutoff here would let the
    // two disagree whenever someone sets a threshold below the old 0.01kW.
    final gridImporting = (gridKw ?? 0) > 0;
    final gridExporting = (gridKw ?? 0) < 0;
    final batteryDischarging = (batteryKw ?? 0) > 0;
    final batteryCharging = (batteryKw ?? 0) < 0;
    final solarActive = (solarKw ?? 0) > 0;

    // Each link's dot speed is driven by the *receiving* end's own
    // magnitude, not the sender's — home is the receiver for all three
    // source links, so all three read homeKw; solar->battery has no
    // dedicated sub-flow reading on this card, so it reuses the battery's
    // own charging power, since battery is the receiver there.
    final gridToHomeKw = (homeKw ?? 0).abs();
    final solarToBatteryKw = (batteryKw ?? 0).abs();
    final solarToHomeKw = (homeKw ?? 0).abs();
    final batteryToHomeKw = (homeKw ?? 0).abs();

    // Same per-slot magnitude, fixed at 4 entries (0 for a slot with no
    // sensor configured, or an unavailable/non-numeric reading) so the mesh
    // painter can always index it regardless of how many sensors exist.
    final individualSensorKw = [
      for (var i = 0; i < _individualSensorSlots.length; i++) i < sensorReadings.length ? (sensorReadings[i].kw ?? 0.0) : 0.0,
    ];

    // Which HOME's load each source is currently supplying, for the ring
    // and conic fill — derived from the same readings driving the nodes,
    // never hardcoded, so ring/gradient and node numbers can't disagree.
    final solarSupply = solarActive ? solarKw! : 0.0;
    final batterySupply = batteryDischarging ? batteryKw! : 0.0;
    final gridSupply = gridImporting ? gridKw! : 0.0;
    final totalSupply = solarSupply + batterySupply + gridSupply;
    final solarShare = totalSupply > 0 ? solarSupply / totalSupply : 0.0;
    final batteryShare = totalSupply > 0 ? batterySupply / totalSupply : 0.0;
    final gridShare = totalSupply > 0 ? gridSupply / totalSupply : 0.0;

    return Card(
      color: NocturneColors.surface,
      child: Stack(
        children: [
          const Positioned(
            top: 20,
            left: 22,
            child: Text(
              'ENERGIA',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 1.3, color: NocturneColors.accent),
            ),
          ),
          Positioned.fill(
            top: 30,
            left: 10,
            right: 10,
            bottom: 22,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                // Only the painted mesh depends on _progress — the node
                // widgets below are siblings outside AnimatedBuilder's
                // scope, so they're built once per real data change
                // instead of 20 times a second.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      // Isolates the 20fps mesh repaint to its own layer —
                      // without this, `CustomPaint` isn't itself a repaint
                      // boundary, so every tick's repaint would bleed up
                      // into the sibling node widgets below (icons,
                      // gradients, text) instead of staying contained here.
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _elapsedMs,
                          builder: (context, _) => CustomPaint(
                            painter: _MeshPainter(
                              elapsedMs: _elapsedMs.value,
                              size: size,
                              gridToHomeActive: gridImporting,
                              solarToBatteryActive: solarActive && batteryCharging,
                              solarToHomeActive: solarActive,
                              batteryToHomeActive: batteryDischarging,
                              gridToHomeKw: gridToHomeKw,
                              solarToBatteryKw: solarToBatteryKw,
                              solarToHomeKw: solarToHomeKw,
                              batteryToHomeKw: batteryToHomeKw,
                              individualSensorKw: individualSensorKw,
                              individualSensorCount: sensors.length,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _node(
                      size,
                      _gridPos,
                      _SourceNode(
                        iconWidget: const GridTowerIcon(size: 30, color: NocturneColors.gridMark),
                        mark: NocturneColors.gridMark,
                        haloMix: 0.20,
                        kw: gridKw?.abs(),
                        badge: gridImporting
                            ? const _DirectionBadge(icon: Icons.arrow_forward, fill: NocturneColors.gridMark)
                            : gridExporting
                            ? const _DirectionBadge(icon: Icons.arrow_back, fill: NocturneColors.gridMark)
                            : null,
                      ),
                    ),
                    _node(
                      size,
                      _solarPos,
                      _SourceNode(icon: Icons.wb_sunny_outlined, mark: NocturneColors.solarMark, haloMix: 0.22, kw: solarKw),
                    ),
                    _node(
                      size,
                      _batteryPos,
                      _SourceNode(
                        icon: Icons.battery_charging_full,
                        mark: NocturneColors.batteryMark,
                        haloMix: 0.20,
                        kw: batteryKw?.abs(),
                        badge: batteryDischarging
                            ? const _DirectionBadge(icon: Icons.arrow_upward, fill: NocturneColors.batteryMark)
                            : batteryCharging
                            ? const _DirectionBadge(icon: Icons.arrow_downward, fill: NocturneColors.batteryMark)
                            : null,
                        socPill: batterySoc == null ? null : _SocPill(soc: batterySoc),
                      ),
                    ),
                    _node(
                      size,
                      _homePos,
                      _HomeHub(kw: homeKw, solarShare: solarShare, batteryShare: batteryShare, gridShare: gridShare),
                    ),
                    for (var i = 0; i < sensors.length && i < _individualSensorSlots.length; i++)
                      _node(
                        size,
                        _individualSensorSlots[i],
                        _ApplianceNode(
                          icon: sensors[i].icon,
                          label: sensors[i].name,
                          kwText: _formatKw(sensorReadings[i].kw),
                          temperatureText: sensorReadings[i].temperature,
                        ),
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

  /// Centers [child] on the given fractional point — Flutter equivalent of
  /// the spec's `transform: translate(-50%,-50%)`, independent of the
  /// child's actual size.
  Widget _node(Size area, Offset fraction, Widget child) {
    final center = Offset(area.width * fraction.dx, area.height * fraction.dy);
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
    );
  }
}

/// The idle grey mesh, the four real-data flows (one traveling particle
/// each — solar→battery, solar→home, grid→home, battery→home), and the two
/// appliance-column links to the individual-sensor device nodes — every one
/// of those dots moves at a speed driven by real wattage via [_flowRate],
/// none of them a fixed decorative rate.
class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.elapsedMs,
    required this.size,
    required this.gridToHomeActive,
    required this.solarToBatteryActive,
    required this.solarToHomeActive,
    required this.batteryToHomeActive,
    required this.gridToHomeKw,
    required this.solarToBatteryKw,
    required this.solarToHomeKw,
    required this.batteryToHomeKw,
    required this.individualSensorKw,
    required this.individualSensorCount,
  });

  final double elapsedMs;
  final Size size;
  final bool gridToHomeActive;
  final bool solarToBatteryActive;
  final bool solarToHomeActive;
  final bool batteryToHomeActive;

  /// Each link's *receiving* end's magnitude, in kW — drives that flow's
  /// dot speed via [_flowRate]. Home receives all three source flows, so
  /// all three read homeKw; battery is the receiver for solar->battery.
  /// Unused while the corresponding *Active flag is false.
  final double gridToHomeKw;
  final double solarToBatteryKw;
  final double solarToHomeKw;
  final double batteryToHomeKw;

  /// One entry per `_individualSensorSlots` index (0 for an unconfigured
  /// slot) — each appliance is the *receiver* of its own link (home
  /// supplies it, not the other way around), so this is that device's own
  /// reading, same rule as the four fields above.
  final List<double> individualSensorKw;

  /// How many of the 4 slots actually have a configured sensor — gates
  /// which appliance-column links get drawn at all, so a link never points
  /// at an empty slot with no node rendered there.
  final int individualSensorCount;

  Offset _p(Offset fraction) => Offset(fraction.dx * size.width, fraction.dy * size.height);

  /// Each flow's own position along its path: true elapsed time modulo that
  /// flow's own duration, so every flow completes a full 0→1 loop on its
  /// own schedule. Deriving this from a shared progress value that itself
  /// wrapped on a fixed cycle (the previous approach) broke any flow whose
  /// duration exceeded that cycle — the shared value would wrap and reset
  /// the flow's phase before it reached 1.0, so the dot visibly snapped
  /// back partway along its path instead of reaching the far end.
  double _phase(Duration flowDuration) {
    final ms = flowDuration.inMilliseconds;
    return (elapsedMs % ms) / ms;
  }

  /// How power-flow-card-plus (the reference Home Assistant Lovelace card
  /// this design started from) picks a flow line's dot speed: linearly
  /// interpolated between the slowest and fastest allowed duration, based
  /// on where *that link's own* power reading falls between an expected
  /// min/max — a 1.5kW flow always looks the same speed regardless of what
  /// any other line on the card is doing. This is its "new flow rate
  /// model" (the project's default), ported from `computeFlowRate`/
  /// `newFlowRate`/`newFlowRateMapRange` in
  /// `packages/shared/src/utils/compute-flow-rate.ts` of the
  /// flixlix/flixlix-cards monorepo; the constants below are that
  /// project's own defaults (`min/max_expected_power` 0.01/2000 W,
  /// `min/max_flow_rate` 0.75/6 s), just expressed in kW to match how this
  /// card already reads power everywhere else.
  static Duration _flowRate(double kw) {
    const minExpectedKw = 0.00001;
    const maxExpectedKw = 2.0;
    const minRateMs = 750;
    const maxRateMs = 6000;
    if (kw >= maxExpectedKw) return const Duration(milliseconds: minRateMs);
    final ratio = (kw - minExpectedKw) / (maxExpectedKw - minExpectedKw);
    final ms = maxRateMs + ratio * (minRateMs - maxRateMs);
    return Duration(milliseconds: ms.round().clamp(minRateMs, maxRateMs));
  }

  @override
  void paint(Canvas canvas, Size _) {
    final meshPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = NocturneColors.neutral800;

    // Idle mesh: Solar -> Grid -> Battery -> Home, as quadratic curves
    // (control points lifted straight from the build spec).
    canvas.drawPath(
      Path()
        ..moveTo(_p(_solarPos).dx, _p(_solarPos).dy)
        ..quadraticBezierTo(_p(const Offset(0.3625, 0.481)).dx, _p(const Offset(0.3625, 0.481)).dy, _p(_gridPos).dx, _p(_gridPos).dy),
      meshPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(_p(_gridPos).dx, _p(_gridPos).dy)
        ..quadraticBezierTo(_p(const Offset(0.3625, 0.519)).dx, _p(const Offset(0.3625, 0.519)).dy, _p(_batteryPos).dx, _p(_batteryPos).dy),
      meshPaint,
    );
    _flowCurve(
      canvas,
      _batteryPos,
      const Offset(0.3875, 0.519),
      _homePos,
      active: batteryToHomeActive,
      color: NocturneColors.batteryMark,
      phase: _phase(_flowRate(batteryToHomeKw)),
    );

    _flowLine(
      canvas,
      _solarPos,
      _batteryPos,
      active: solarToBatteryActive,
      color: NocturneColors.solarLine,
      phase: _phase(_flowRate(solarToBatteryKw)),
    );
    _flowCurve(
      canvas,
      _solarPos,
      const Offset(0.3875, 0.481),
      _homePos,
      active: solarToHomeActive,
      color: NocturneColors.solarLine,
      phase: _phase(_flowRate(solarToHomeKw)),
    );
    _flowLine(
      canvas,
      _gridPos,
      _homePos,
      active: gridToHomeActive,
      color: NocturneColors.gridLine,
      phase: _phase(_flowRate(gridToHomeKw)),
    );

    // Column A: single straight bus behind the home node, shared by both
    // its devices — its dot speed reflects their combined draw, since the
    // reference flow-rate model has no notion of two loads on one
    // connector. Only drawn once both slots it spans actually have a
    // sensor — sensors fill slots 0..count-1 in order, so a lone slot-0
    // sensor with no slot-1 partner gets no dangling line into an empty
    // position.
    if (individualSensorCount >= 2) {
      _ambientLine(canvas, _individualSensorSlots[0], _individualSensorSlots[1], dur: _flowRate(individualSensorKw[0] + individualSensorKw[1]));
    }

    // Column B: each device curves straight into home (mirrors the
    // battery/solar -> home curves above, reflected about the home column)
    // — one line per device, so each dot speed is that device's own kW,
    // and each is only drawn once its own slot has a sensor.
    if (individualSensorCount >= 3) {
      _ambientCurve(canvas, _individualSensorSlots[2], const Offset(0.8875, 0.481), _homePos, dur: _flowRate(individualSensorKw[2]));
    }
    if (individualSensorCount >= 4) {
      _ambientCurve(canvas, _individualSensorSlots[3], const Offset(0.8875, 0.519), _homePos, dur: _flowRate(individualSensorKw[3]));
    }
  }

  void _flowLine(Canvas canvas, Offset fromF, Offset toF, {required bool active, required Color color, required double phase}) {
    final from = _p(fromF);
    final to = _p(toF);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = active ? color : NocturneColors.neutral800,
    );
    if (!active) return;
    canvas.drawCircle(Offset.lerp(from, to, phase)!, 1.35 * (size.height / 100), Paint()..color = color);
  }

  void _flowCurve(
    Canvas canvas,
    Offset fromF,
    Offset controlF,
    Offset toF, {
    required bool active,
    required Color color,
    required double phase,
  }) {
    final from = _p(fromF);
    final control = _p(controlF);
    final to = _p(toF);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = active ? color : NocturneColors.neutral800,
    );
    if (!active) return;
    canvas.drawCircle(_quadraticPoint(from, control, to, phase), 1.35 * (size.height / 100), Paint()..color = color);
  }

  static Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx,
      mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy,
    );
  }

  /// A grey link whose dot loops continuously along it (no fade at the
  /// ends, unlike the old spine) — used for the appliance-column links,
  /// which never carry live data on this card, unlike `_flowLine`/
  /// `_flowCurve`'s dot that only appears while a real transfer is active.
  void _ambientLine(Canvas canvas, Offset fromF, Offset toF, {required Duration dur}) {
    final from = _p(fromF);
    final to = _p(toF);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = NocturneColors.neutral800,
    );
    canvas.drawCircle(Offset.lerp(from, to, _phase(dur))!, 1.35 * (size.height / 100), Paint()..color = NocturneColors.neutral500);
  }

  void _ambientCurve(Canvas canvas, Offset fromF, Offset controlF, Offset toF, {required Duration dur}) {
    final from = _p(fromF);
    final control = _p(controlF);
    final to = _p(toF);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = NocturneColors.neutral800,
    );
    canvas.drawCircle(_quadraticPoint(from, control, to, _phase(dur)), 1.35 * (size.height / 100), Paint()..color = NocturneColors.neutral500);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.elapsedMs != elapsedMs ||
        oldDelegate.gridToHomeActive != gridToHomeActive ||
        oldDelegate.solarToBatteryActive != solarToBatteryActive ||
        oldDelegate.solarToHomeActive != solarToHomeActive ||
        oldDelegate.batteryToHomeActive != batteryToHomeActive ||
        oldDelegate.gridToHomeKw != gridToHomeKw ||
        oldDelegate.solarToBatteryKw != solarToBatteryKw ||
        oldDelegate.solarToHomeKw != solarToHomeKw ||
        oldDelegate.batteryToHomeKw != batteryToHomeKw ||
        oldDelegate.individualSensorCount != individualSensorCount ||
        !listEquals(oldDelegate.individualSensorKw, individualSensorKw);
  }
}

/// Grid/Solar/Battery: a 100px circle with a role-tinted halo background,
/// an icon + kW reading in the role's "mark" colour, an optional direction
/// badge, and (battery only) a state-of-charge pill.
class _SourceNode extends StatelessWidget {
  const _SourceNode({this.icon, this.iconWidget, required this.mark, required this.haloMix, required this.kw, this.badge, this.socPill})
    : assert(icon != null || iconWidget != null);

  final IconData? icon;

  /// Overrides [icon] for glyphs Flutter's Material set doesn't have (the
  /// grid node's transmission tower) — see `GridTowerIcon`.
  final Widget? iconWidget;
  final Color mark;
  final double haloMix;
  final double? kw;
  final Widget? badge;
  final Widget? socPill;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _sourceDiameter,
          height: _sourceDiameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(mark.withValues(alpha: haloMix), NocturneColors.surface),
            boxShadow: const [BoxShadow(color: NocturneColors.surface, spreadRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ?? Icon(icon, size: 30, color: mark),
              const SizedBox(height: 6),
              Text(_formatKw(kw), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: mark)),
            ],
          ),
        ),
        if (badge != null) Positioned(top: -2, right: -2, child: badge!),
        if (socPill != null) Positioned(bottom: -8, left: 0, right: 0, child: Center(child: socPill!)),
      ],
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({required this.icon, required this.fill});

  final IconData icon;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, boxShadow: const [BoxShadow(color: NocturneColors.surface, spreadRadius: 5)]),
      child: Icon(icon, size: 15, color: NocturneColors.bg),
    );
  }
}

class _SocPill extends StatelessWidget {
  const _SocPill({required this.soc});

  final double soc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        color: NocturneColors.batteryMark,
        borderRadius: BorderRadius.circular(NocturneRadii.pill),
        boxShadow: const [BoxShadow(color: NocturneColors.surface, spreadRadius: 5)],
      ),
      child: Text(
        '${soc.round()}%',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, color: NocturneColors.bg),
      ),
    );
  }
}

/// The house hub: a stacked-donut ring (each source's share of the current
/// home load) around a conic-tinted disc, with the house icon + total kW
/// in the middle. Ring segments and the gradient stops both come straight
/// from the same shares — never hardcoded — so they can't disagree.
class _HomeHub extends StatelessWidget {
  const _HomeHub({required this.kw, required this.solarShare, required this.batteryShare, required this.gridShare});

  final double? kw;
  final double solarShare;
  final double batteryShare;
  final double gridShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _homeDiameter,
      height: _homeDiameter,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: NocturneColors.surface, boxShadow: [BoxShadow(color: NocturneColors.surface, spreadRadius: 8)]),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_homeDiameter, _homeDiameter),
            painter: _RingPainter(solarShare: solarShare, batteryShare: batteryShare, gridShare: gridShare),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            // DecoratedBox has no intrinsic size of its own — without an
            // explicit child to fill, it collapses to zero size inside the
            // Stack's loose constraints and the gradient never paints.
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: const GradientRotation(-math.pi / 2),
                  colors: [
                    Color.alphaBlend(NocturneColors.solarMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                    Color.alphaBlend(NocturneColors.solarMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                    Color.alphaBlend(NocturneColors.batteryMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                    Color.alphaBlend(NocturneColors.batteryMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                    Color.alphaBlend(NocturneColors.gridMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                    Color.alphaBlend(NocturneColors.gridMark.withValues(alpha: 0.3), NocturneColors.neutral900),
                  ],
                  stops: [
                    0,
                    solarShare,
                    solarShare,
                    solarShare + batteryShare,
                    solarShare + batteryShare,
                    1.0,
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_outlined, size: 26, color: NocturneColors.text),
              const SizedBox(height: 4),
              Text(_formatKw(kw), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NocturneColors.text)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.solarShare, required this.batteryShare, required this.gridShare});

  final double solarShare;
  final double batteryShare;
  final double gridShare;

  // The build spec's example segment lengths (185/66/21 for shares
  // 0.65/0.25/0.10 around a r=47.5 circle) back out to "proportional share
  // of the circumference, minus a fixed ~9-unit gap" — reproduced here as a
  // formula instead of those three literal numbers, so it stays correct
  // for whatever the real shares are.
  static const _ringGapUnits = 9.0;
  static const _radius = 47.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = NocturneColors.neutral800,
    );

    final circumference = 2 * math.pi * _radius;
    final gapAngle = (_ringGapUnits / circumference) * 2 * math.pi;

    var angle = -math.pi / 2; // 12 o'clock, matching the reference's rotate(-90deg).
    void segment(double share, Color color) {
      final full = share * 2 * math.pi;
      if (share > 0) {
        final sweep = (full - gapAngle).clamp(0.0, full);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _radius),
          angle,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      angle += full;
    }

    segment(solarShare, NocturneColors.solarMark);
    segment(batteryShare, NocturneColors.batteryMark);
    segment(gridShare, NocturneColors.gridMark);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.solarShare != solarShare || oldDelegate.batteryShare != batteryShare || oldDelegate.gridShare != gridShare;
  }
}

/// A device node: 92px neutral disc (icon + kW, and — when the sensor has a
/// temperature entity configured, e.g. a hot-water tank — a temperature
/// reading above the icon) with a caption below.
class _ApplianceNode extends StatelessWidget {
  const _ApplianceNode({required this.icon, required this.label, required this.kwText, this.temperatureText});

  final IndividualSensorIconKey icon;
  final String label;
  final String kwText;
  final String? temperatureText;

  @override
  Widget build(BuildContext context) {
    final temperatureText = this.temperatureText;
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _applianceDiameter,
            height: _applianceDiameter,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: NocturneColors.neutral800,
              boxShadow: [BoxShadow(color: NocturneColors.surface, spreadRadius: 6)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (temperatureText != null) ...[
                  Text(
                    temperatureText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NocturneColors.neutral400, height: 1.0),
                  ),
                  const SizedBox(height: 3),
                ],
                individualSensorIcon(icon, size: 22, color: NocturneColors.neutral300),
                const SizedBox(height: 3),
                Text(kwText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NocturneColors.neutral200)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: NocturneColors.neutral500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
