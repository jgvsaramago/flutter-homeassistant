import 'dart:async';

import 'package:flutter/material.dart';

import '../services/screen_power_controller.dart';
import '../services/screen_power_service.dart';

const _idleTimeout = Duration(minutes: 2);

/// Wraps the whole app: blanks the physical screen after [_idleTimeout] of
/// no touch input, and wakes it again on the next touch — without that
/// wake-up touch reaching whatever screen/button happened to be under it.
///
/// The wake touch is swallowed by construction, not by convention: while
/// off, an opaque full-screen [Listener] sits on top of [child] in the
/// [Stack] and is the only thing at that z-index that claims the pointer,
/// so normal Flutter hit-testing never lets the event reach [child] at all
/// (the same mechanism a modal barrier uses to block the content behind it).
class ScreenPowerGuard extends StatefulWidget {
  const ScreenPowerGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ScreenPowerGuard> createState() => _ScreenPowerGuardState();
}

class _ScreenPowerGuardState extends State<ScreenPowerGuard> {
  static final _service = ScreenPowerService();

  /// True once this *process* has run the "wake in case the previous
  /// process left the hardware blanked" recovery below — a widget remount
  /// (the whole app remounts on a theme switch; see `ThemeModeController`/
  /// `app.dart`) isn't a fresh process launch and must not repeat it, or
  /// it would force the screen back on even when it had just been
  /// correctly, deliberately turned off moments before.
  static bool _recoveredThisProcess = false;

  Timer? _idleTimer;

  /// Seeded from the controller's last known state, not a hardcoded
  /// `false` — `ScreenPowerController.instance` is a singleton that
  /// survives a widget remount, so this keeps `_screenOff` in sync with
  /// reality across one instead of silently resetting to "on" (and then
  /// silently no-op'ing the next real "turn on" command, since `_applyPower`
  /// treats that as already being in the requested state) every time the
  /// app remounts.
  late bool _screenOff = !ScreenPowerController.instance.isOn.value;

  @override
  void initState() {
    super.initState();
    ScreenPowerController.instance.attach(_applyPowerExternal);
    if (!_service.isSupported) return;
    if (!_recoveredThisProcess) {
      _recoveredThisProcess = true;
      // The backlight/panel-off sysfs writes outlive the process that made
      // them — if this app got killed (not cleanly closed) while the screen
      // was blanked, the hardware is still off when we relaunch, even though
      // this fresh instance's _screenOff starts false and has no way to know
      // that. Unconditionally waking on every process launch is what
      // actually fixes that, rather than trying to detect and special-case
      // it — but only ever once per process, guarded by the flag above.
      _service.setPowered(true);
    }
    _resetIdleTimer();
  }

  @override
  void dispose() {
    ScreenPowerController.instance.detach(_applyPowerExternal);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _turnOff);
  }

  /// Applies an on/off change from any source (the idle timer, a touch, or
  /// an MQTT command) through one path, so `_screenOff` — and the overlay
  /// that depends on it — never drifts out of sync with the real state.
  ///
  /// No-ops if the screen is already in the requested state. This matters
  /// beyond just avoiding redundant sysfs writes: HA's MQTT light sends
  /// `ON` to the power topic on *every* brightness change, not just an
  /// actual power-on (setting brightness is implemented as
  /// `turn_on(brightness_pct=...)`), and `_service.setPowered(true)`
  /// restores whatever brightness was saved when the screen last went off —
  /// which, racing against the brightness command that prompted this "ON"
  /// in the first place, could finish second and clobber the value the user
  /// just set. Skipping the call entirely when already on removes the race
  /// rather than trying to win it.
  ///
  /// `_screenOff` (and `isOn`) flip via `onMidTransition`, not at the start
  /// or end of this call — `ScreenPowerService.setPowered` fires that at the
  /// exact moment the panel is actually fully dark or actually fully
  /// revealed, so the touch-swallowing overlay and every screen-power-aware
  /// listener (entity/MASS buffering, the energy card's mesh timer, the MQTT
  /// screen-state topic) change state in step with what's physically on
  /// screen rather than at the start of a still-fading transition.
  Future<void> _applyPower(bool on) async {
    if (!mounted || on == !_screenOff) return;
    _idleTimer?.cancel();
    await _service.setPowered(
      on,
      onMidTransition: () {
        if (!mounted) return;
        setState(() => _screenOff = !on);
        ScreenPowerController.instance.isOn.value = on;
      },
    );
    if (on) _resetIdleTimer();
  }

  void _applyPowerExternal(bool on) => _applyPower(on);

  Future<void> _turnOff() => _applyPower(false);

  Future<void> _wake(PointerDownEvent _) {
    // Only reachable while the screen is off (see build() — the overlay
    // this is wired to only exists then), so _applyPower always runs its
    // full body here and calls _resetIdleTimer() itself; no need to here.
    return _applyPower(true);
  }

  void _onActivity(PointerEvent _) => _resetIdleTimer();

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return widget.child;

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onActivity,
          onPointerMove: _onActivity,
          onPointerSignal: _onActivity,
          child: widget.child,
        ),
        if (_screenOff)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _wake,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
      ],
    );
  }
}
