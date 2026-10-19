import 'dart:io';

import 'ddc_ci.dart';

/// Screen brightness: over DDC/CI when the screen is an external monitor
/// that speaks it (the kiosk's HDMI panel — see [DdcCi]), otherwise Linux
/// backlight control via `/sys/class/backlight/<device>/brightness`.
/// The device directory name varies by panel/kernel (the official 7" touch
/// display shows up as `rpi_backlight` on most images, `10-0045` on older
/// ones), so rather than hardcoding one, this picks whichever single
/// backlight device the kernel exposes — a Pi with one DSI touchscreen only
/// ever has one.
///
/// Writing `brightness` needs permission on the sysfs file; Raspberry Pi OS
/// ships a udev rule that makes it world-writable, but a from-scratch image
/// or a non-standard panel driver might not, so every write is guarded and
/// reports success/failure rather than throwing.
class ScreenBrightnessService {
  const ScreenBrightnessService();

  static const _backlightRoot = '/sys/class/backlight';

  Directory? _backlightDir() {
    if (!Platform.isLinux) return null;
    final base = Directory(_backlightRoot);
    if (!base.existsSync()) return null;
    final devices = base.listSync().whereType<Directory>().toList();
    return devices.isEmpty ? null : devices.first;
  }

  /// True on any Linux device: DDC/CI availability is only known after an
  /// async probe, and a failed probe falls back to the backlight anyway.
  bool get isSupported => Platform.isLinux;

  Future<int?> readPercent() async {
    if (await DdcCi.instance.isAvailable) return DdcCi.instance.readBrightness();
    final dir = _backlightDir();
    if (dir == null) return null;
    try {
      final brightness = int.parse((await File('${dir.path}/brightness').readAsString()).trim());
      final max = int.parse((await File('${dir.path}/max_brightness').readAsString()).trim());
      if (max <= 0) return null;
      return ((brightness / max) * 100).round().clamp(0, 100);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setPercent(int percent) async {
    if (await DdcCi.instance.isAvailable) return DdcCi.instance.setBrightness(percent);
    final dir = _backlightDir();
    if (dir == null) return false;
    try {
      final max = int.parse((await File('${dir.path}/max_brightness').readAsString()).trim());
      final value = (percent.clamp(0, 100) / 100 * max).round();
      await File('${dir.path}/brightness').writeAsString('$value');
      return true;
    } catch (_) {
      return false;
    }
  }
}
