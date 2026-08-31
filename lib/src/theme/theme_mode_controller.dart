import 'package:flutter/material.dart';

import 'theme_mode_store.dart';

/// App-wide handle onto the current light/dark [Brightness] — same shape as
/// `ScreenPowerController`: a `BuildContext`-free singleton so code that has
/// none (the MQTT publisher, commanded remotely from Home Assistant) can
/// still drive it. `NocturneColors`/`NocturneText`/`NocturneElevation` all
/// read [mode] to decide which palette to return, and `HomeAssistantApp`
/// remounts its whole subtree on every change (see `app.dart`) — Dart's
/// `const` evaluates those tokens once at compile time everywhere else, so
/// changing this value alone doesn't repaint anything by itself; the remount
/// is what makes every widget re-read the token getters with the new mode.
class ThemeModeController {
  ThemeModeController._();

  static final instance = ThemeModeController._();

  final ValueNotifier<Brightness> mode = ValueNotifier(Brightness.dark);

  final _store = ThemeModeStore();

  /// Restores the last-saved mode, if any — call once at startup, before
  /// `runApp`, so the first frame already paints in the right theme instead
  /// of flashing dark then swapping.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved != null) mode.value = saved;
  }

  /// Sets the theme and persists it, so it survives a kiosk reboot without
  /// needing Home Assistant to resend the command.
  Future<void> setMode(Brightness value) async {
    mode.value = value;
    await _store.save(value);
  }
}
