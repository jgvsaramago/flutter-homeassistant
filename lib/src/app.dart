import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev/placeholder_entities.dart';
import 'pages/main_shell.dart';
import 'providers/ha_providers.dart';
import 'theme/nocturne_theme.dart';
import 'theme/theme_mode_controller.dart';
import 'widgets/on_screen_keyboard.dart';
import 'widgets/screen_power_guard.dart';

@Preview(name: 'Home Assistant App', size: Size(720, 1920))
Widget homeAssistantAppPreview() {
  return ProviderScope(overrides: placeholderOverrides, child: const HomeAssistantApp());
}

class HomeAssistantApp extends StatelessWidget {
  const HomeAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `NocturneColors`/`NocturneText`/`NocturneElevation` are plain
    // `static Color get`s reading `ThemeModeController.instance.mode` at
    // call time — they aren't `Listenable` themselves, so nothing rebuilds
    // just because that value changed. Rebuilding `MaterialApp` under a
    // `ValueKey` on the mode forces Flutter to tear down and remount the
    // *entire* subtree on a theme switch, which is what actually makes
    // every widget re-read those getters with the new mode — the
    // alternative (wiring every single one of this app's ~500 token call
    // sites to its own listener) isn't remotely worth it for something a
    // person changes a few times a year, not per frame.
    return ValueListenableBuilder<Brightness>(
      valueListenable: ThemeModeController.instance.mode,
      builder: (context, mode, _) => MaterialApp(
        key: ValueKey(mode),
        title: 'Home Assistant',
        debugShowCheckedModeBanner: false,
        theme: buildNocturneTheme(),
        darkTheme: buildNocturneTheme(),
        themeMode: mode == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        // Wraps the Navigator (dialogs included) so the auto-off overlay and
        // the on-screen keyboard both sit above literally everything the app
        // can show. Keyboard nested inside the power guard so tapping it
        // still counts as activity for the auto-off idle timer.
        //
        // The `DefaultTextStyle.merge` here is belt-and-suspenders on top of
        // `ThemeData.fontFamily` below: every `Text` with a custom
        // `TextStyle` already inherits an unset `fontFamily` from the
        // nearest `DefaultTextStyle` (which itself is normally seeded from
        // `Theme.of(context).textTheme`) — but forcing it explicitly here,
        // above the whole subtree, means Inter applies regardless of
        // whatever ends up between here and any given `Text` (a `Sheet`
        // pushed via a bare `PageRouteBuilder`, e.g. — see `NocturneText`'s
        // own doc comment about that same gap for `TextDecoration.none`).
        builder: (context, child) => DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Inter'),
          child: ScreenPowerGuard(child: OnScreenKeyboardHost(child: child!)),
        ),
        home: const RootScreen(),
      ),
    );
  }
}

/// Loads any saved connection config once at startup (there's no onboarding
/// UI — this kiosk is only ever configured via `--ha-url`/`--ha-token` on
/// the launch command, see `main.dart`), then shows the dashboard. Missing
/// config isn't treated as an error here: `entitiesProvider` just resolves
/// to an empty entity set, which the dashboard already renders sensibly
/// (badges at zero, readings as "--"), and Settings' "Instance"/"Status"
/// rows make a misconfigured launch command visible without blocking on it.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // Only the HA connection config is read here — it's still local/instant
  // (SharedPreferences), and setting `connectionConfigProvider` is what
  // triggers `entitiesProvider` to start connecting in the background.
  // Every dashboard-config setting now lives behind that connection (see
  // `settingsHydrationProvider` in `ha_providers.dart`), so loading them is
  // `MainShell`'s job — it already has proper loading/error/retry UI for
  // "waiting on HA", unlike this bare spinner.
  Future<void> _bootstrap() async {
    try {
      final saved = await ref.read(savedConnectionConfigProvider.future);
      if (saved != null) {
        ref.read(connectionConfigProvider.notifier).state = saved;
      }
    } catch (_) {
      // No usable local storage (or nothing saved yet) — proceed with no config.
    }
    if (mounted) setState(() => _bootstrapped = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const MainShell();
  }
}
