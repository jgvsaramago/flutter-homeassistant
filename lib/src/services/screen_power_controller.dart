import 'package:flutter/foundation.dart';

/// App-wide handle onto the live `ScreenPowerGuard` instance's on/off state
/// and control — lets code with no `BuildContext` (the MQTT publisher,
/// commanded remotely from Home Assistant) query/drive the screen without
/// bypassing `ScreenPowerGuard`'s own state machine. Driving the hardware
/// directly instead would desync its `_screenOff` flag from reality: e.g.
/// an MQTT-triggered "off" that skipped it would leave the touch-swallowing
/// overlay absent, so the next touch would both wake the screen *and* land
/// on whatever the app was showing — exactly the bug that overlay exists to
/// prevent.
class ScreenPowerController {
  ScreenPowerController._();

  static final instance = ScreenPowerController._();

  /// Mirrors whether the screen is currently on. `ScreenPowerGuard` keeps
  /// this in sync; nothing else should write to it.
  final ValueNotifier<bool> isOn = ValueNotifier(true);

  void Function(bool on)? _handler;

  void attach(void Function(bool on) handler) => _handler = handler;

  /// Only clears [_handler] if it's still [handler] — not unconditionally.
  /// The app can remount its whole subtree at runtime (a theme switch; see
  /// `ThemeModeController`/`app.dart`), which tears down the old
  /// `ScreenPowerGuard` and mounts a fresh one. If the old instance's
  /// `dispose()` (and thus this call) happens to run *after* the new
  /// instance's `initState()` has already re-attached, an unconditional
  /// `_handler = null` here would wipe out that fresh registration and
  /// leave every later MQTT screen command silently no-op'd forever — this
  /// was a real, reproduced bug, not a hypothetical one. Dart guarantees
  /// two tear-offs of the same instance method from the same receiver
  /// compare `==`, so this comparison is safe without needing `identical`.
  void detach(void Function(bool on) handler) {
    if (_handler == handler) _handler = null;
  }

  /// Requests the screen be turned on/off. No-op if no `ScreenPowerGuard`
  /// is currently mounted.
  void setPowered(bool on) => _handler?.call(on);
}
