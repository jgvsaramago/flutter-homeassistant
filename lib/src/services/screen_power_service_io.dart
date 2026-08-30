import 'dart:io';

/// Blanks/wakes the actual panel — not just backlight brightness — without
/// touching DRM mode-setting at all. `vcgencmd display_power` (the obvious
/// first choice) is a dead end on a Pi 5 running Bookworm's KMS/Wayland
/// stack; it's a legacy VideoCore-firmware call that stack doesn't route
/// through anymore. Driving DRM directly instead would need this process to
/// hold the DRM master lock, which flutter-pi itself already holds — a
/// second process fighting it for mode-setting risks corrupting or
/// crashing the display flutter-pi is actively driving, so that's off the
/// table too.
///
/// What's left, and what this does, is every independent, non-DRM knob:
/// - the backlight class device's `bl_power` file — on drivers where the
///   panel is wired through `drm_panel`, writing `FB_BLANK_POWERDOWN` here
///   cuts the panel's own power rail (a real power-down, not just PWM=0).
///   On simpler backlight drivers (e.g. the official 7" touchscreen's
///   `rpi_backlight`) it's wired to do the same thing brightness=0 does —
///   still worth writing since it's free, just not guaranteed distinct.
/// - `brightness` itself, zeroed as a baseline that works everywhere.
/// - the fbdev compat blanking ioctl via `/sys/class/graphics/fb0/blank`,
///   which several kernels still route to the DRM connector's DPMS state
///   even under a KMS-only setup, and — unlike raw DRM access — doesn't
///   require taking the master lock away from flutter-pi.
///
/// Every write is independently best-effort: each is attempted and its
/// failure ignored, since which of these actually has an effect depends on
/// the specific panel/kernel driver and can only really be confirmed on the
/// real hardware.
class ScreenPowerService {
  ScreenPowerService();

  static const _backlightRoot = '/sys/class/backlight';
  static const _fbBlankPath = '/sys/class/graphics/fb0/blank';

  bool get isSupported => Platform.isLinux;

  Directory? _backlightDir() {
    if (!Platform.isLinux) return null;
    final base = Directory(_backlightRoot);
    if (!base.existsSync()) return null;
    final devices = base.listSync().whereType<Directory>().toList();
    return devices.isEmpty ? null : devices.first;
  }

  Future<void> _tryWrite(String path, String value) async {
    try {
      await File(path).writeAsString(value);
    } catch (_) {
      // Expected on most of these — see the class doc.
    }
  }

  int? _savedBrightnessPercent;

  /// A visible dim rather than an instant cut needs real intermediate
  /// brightness values written over time — 18 steps across 350ms lands on
  /// a step roughly every frame at 60Hz, smooth without spending long
  /// enough that the fade itself feels sluggish.
  static const _fadeDuration = Duration(milliseconds: 350);
  static const _fadeSteps = 18;

  Future<({int brightness, int max})?> _readBrightness(Directory dir) async {
    try {
      final brightness = int.parse((await File('${dir.path}/brightness').readAsString()).trim());
      final max = int.parse((await File('${dir.path}/max_brightness').readAsString()).trim());
      if (max <= 0) return null;
      return (brightness: brightness, max: max);
    } catch (_) {
      return null;
    }
  }

  /// Ramps `brightness` from [from] to [to] (both raw, not percent) in
  /// [_fadeSteps] writes over [_fadeDuration] — a no-op if they're already
  /// equal, so waking straight into a saved 0% (see below) doesn't pause
  /// for a fade that has nowhere to go.
  Future<void> _fadeBrightness(Directory dir, {required int from, required int to, required int max}) async {
    if (from == to) return;
    final stepDelay = _fadeDuration ~/ _fadeSteps;
    for (var i = 1; i <= _fadeSteps; i++) {
      final value = (from + (to - from) * i / _fadeSteps).round().clamp(0, max);
      await _tryWrite('${dir.path}/brightness', '$value');
      if (i < _fadeSteps) await Future<void>.delayed(stepDelay);
    }
  }

  /// [onMidTransition] fires at the exact moment the panel is fully dark
  /// (going off, right before the hardware blank) or fully revealed (waking,
  /// right after unblanking but before brightness has risen off 0) — the
  /// caller's cue to flip its own on/off UI state exactly when it matches
  /// what's physically on screen, rather than at the start/end of this
  /// call. This is also why the fade direction matters: going off fades
  /// brightness down *while the real UI is still visible* (so the dashboard
  /// itself visibly dims), only blanking once it's already black; waking
  /// unblanks first at brightness 0, reveals the real UI, then fades
  /// brightness up — so the thing brightening is the actual dashboard, not
  /// a static overlay.
  Future<bool> setPowered(bool on, {void Function()? onMidTransition}) async {
    if (!Platform.isLinux) return false;
    final dir = _backlightDir();

    if (!on) {
      final read = dir == null ? null : await _readBrightness(dir);
      if (dir != null) {
        if (read != null) {
          _savedBrightnessPercent = ((read.brightness / read.max) * 100).round().clamp(0, 100);
          await _fadeBrightness(dir, from: read.brightness, to: 0, max: read.max);
        } else {
          // Fall back to full brightness on the next wake, and to an
          // instant cut here — no known current value to fade down from.
          await _tryWrite('${dir.path}/brightness', '0');
        }
      }
      onMidTransition?.call();
      // bl_power last, now that brightness is already at 0: on some
      // backlight drivers a later `brightness` write resets `bl_power`'s
      // stored value as a side effect, which would silently undo this if it
      // came first.
      if (dir != null) await _tryWrite('${dir.path}/bl_power', '4'); // FB_BLANK_POWERDOWN
      await _tryWrite(_fbBlankPath, '1');
      return dir != null;
    }

    if (dir != null) await _tryWrite('${dir.path}/bl_power', '0'); // FB_BLANK_UNBLANK
    await _tryWrite(_fbBlankPath, '0');
    onMidTransition?.call();
    if (dir != null) {
      final read = await _readBrightness(dir);
      if (read != null) {
        // A saved 0% would restore to a literal zero brightness — the panel
        // stays black, `_screenOff` still flips to "on" since bl_power/fb
        // blanking both went through fine, so the touch-swallowing overlay
        // is gone and the *next* touch does nothing visible either: from
        // here the screen never comes back without restarting the app.
        // (Real-world trigger: something wrote brightness to 0 — e.g. Home
        // Assistant's brightness slider on the Screen MQTT light, which
        // most integrations treat as "off" but this app stores as a plain
        // percent — while the screen was still nominally on, so the next
        // sleep cycle read and cached that 0 as "the brightness to restore
        // to".) Always waking to something visible is the actual invariant
        // "wake the screen" needs, so a saved 0 is treated as unset instead.
        final savedPercent = _savedBrightnessPercent;
        final restorePercent = (savedPercent == null || savedPercent <= 0) ? 100 : savedPercent.clamp(0, 100);
        final target = (restorePercent / 100 * read.max).round();
        await _fadeBrightness(dir, from: read.brightness, to: target, max: read.max);
      }
      // else: nothing sensible to restore to — leave brightness as-is.
    }
    return dir != null;
  }
}
