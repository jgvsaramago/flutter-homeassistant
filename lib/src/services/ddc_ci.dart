import 'dart:async';
import 'dart:io';

/// Talks to an external monitor over DDC/CI (the I²C side channel in the
/// HDMI cable) through `ddcutil` — how the kiosk sets brightness and turns
/// the panel off/on now that it's an HDMI monitor with no Linux backlight
/// device of its own. Needs the `ddcutil` package and the `i2c-dev` kernel
/// module on the Pi, and the service user in the `i2c` group.
///
/// Only imported by the `_io` service implementations, so never compiled
/// for web.
class DdcCi {
  DdcCi._();

  static final instance = DdcCi._();

  /// MCCS VCP codes.
  static const _brightness = '10';
  static const _powerMode = 'd6';

  /// `0xD6` values: 1 = on, 4 = off (DPM off; the monitor keeps listening
  /// on DDC, so it can be woken the same way — verified on the HG622J36).
  static const _powerOn = '1';
  static const _powerOff = '4';

  Future<int?>? _bus;

  // ddcutil calls must not overlap — two transactions interleaved on the
  // same I²C bus corrupt each other — so every call queues behind the last.
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() f) {
    final result = _queue.then((_) => f());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The I²C bus of the first DDC-capable display, found once with
  /// `ddcutil detect` (a few hundred ms) and cached. Null when there's no
  /// ddcutil, no i2c-dev, or the monitor doesn't speak DDC/CI.
  Future<int?> bus() => _bus ??= _detect();

  Future<int?> _detect() async {
    if (!Platform.isLinux) return null;
    try {
      final r = await Process.run('ddcutil', ['detect', '--brief']);
      if (r.exitCode != 0) return null;
      final m = RegExp(r'/dev/i2c-(\d+)').firstMatch(r.stdout as String);
      return m == null ? null : int.parse(m.group(1)!);
    } catch (_) {
      return null;
    }
  }

  Future<bool> get isAvailable async => await bus() != null;

  Future<ProcessResult?> _run(List<String> args) async {
    final b = await bus();
    if (b == null) return null;
    return _serial(() async {
      try {
        return await Process.run('ddcutil', ['--bus', '$b', ...args]);
      } catch (_) {
        return ProcessResult(0, 1, '', '');
      }
    });
  }

  Future<int?> readBrightness() async {
    final r = await _run(['getvcp', _brightness, '--brief']);
    if (r == null || r.exitCode != 0) return null;
    // "VCP 10 C 100 100" — current, then max.
    final parts = (r.stdout as String).trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return null;
    final current = int.tryParse(parts[3]), max = int.tryParse(parts[4]);
    if (current == null || max == null || max <= 0) return null;
    return (current / max * 100).round().clamp(0, 100);
  }

  /// Latest-wins: a burst of requests (HA's slider, or dragging the
  /// in-app one) collapses to one write of the final value instead of
  /// queueing every intermediate step on the slow I²C bus.
  int? _pendingBrightness;
  Future<bool>? _brightnessWrite;

  Future<bool> setBrightness(int percent) {
    _pendingBrightness = percent.clamp(0, 100);
    return _brightnessWrite ??= () async {
      var ok = false;
      while (_pendingBrightness != null) {
        final value = _pendingBrightness!;
        _pendingBrightness = null;
        final r = await _run(['setvcp', _brightness, '$value']);
        ok = r != null && r.exitCode == 0;
      }
      _brightnessWrite = null;
      return ok;
    }();
  }

  Future<bool> setPower(bool on) async {
    final r = await _run(['setvcp', _powerMode, on ? _powerOn : _powerOff]);
    return r != null && r.exitCode == 0;
  }
}
