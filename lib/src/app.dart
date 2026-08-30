import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev/placeholder_entities.dart';
import 'pages/main_shell.dart';
import 'providers/ha_providers.dart';
import 'theme/nocturne_theme.dart';
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
    return MaterialApp(
      title: 'Home Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildNocturneTheme(),
      darkTheme: buildNocturneTheme(),
      themeMode: ThemeMode.dark,
      // Wraps the Navigator (dialogs included) so the auto-off overlay and
      // the on-screen keyboard both sit above literally everything the app
      // can show. Keyboard nested inside the power guard so tapping it
      // still counts as activity for the auto-off idle timer.
      builder: (context, child) => ScreenPowerGuard(child: OnScreenKeyboardHost(child: child!)),
      home: const RootScreen(),
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
