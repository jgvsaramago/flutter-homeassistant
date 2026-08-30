import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev/placeholder_entities.dart';
import 'pages/main_shell.dart';
import 'providers/calendar_entities_provider.dart';
import 'providers/energy_entities_provider.dart';
import 'providers/energy_page_settings_provider.dart';
import 'providers/ev_cars_provider.dart';
import 'providers/ha_providers.dart';
import 'providers/individual_sensors_provider.dart';
import 'providers/mass_providers.dart';
import 'providers/rooms_provider.dart';
import 'providers/temperature_entities_provider.dart';
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

  Future<void> _bootstrap() async {
    try {
      final saved = await ref.read(savedConnectionConfigProvider.future);
      if (saved != null) {
        ref.read(connectionConfigProvider.notifier).state = saved;
      }
    } catch (_) {
      // No usable local storage (or nothing saved yet) — proceed with no config.
    }
    try {
      final savedEnergyEntities = await ref.read(savedEnergyEntityConfigProvider.future);
      if (!savedEnergyEntities.isEmpty) {
        ref.read(energyEntityConfigProvider.notifier).state = savedEnergyEntities;
      }
    } catch (_) {
      // Proceed with the energy card's own "--" fallback for every field.
    }
    try {
      final savedEnergyPageConfig = await ref.read(savedEnergyPageConfigProvider.future);
      if (!savedEnergyPageConfig.isEmpty) {
        ref.read(energyPageConfigProvider.notifier).state = savedEnergyPageConfig;
      }
    } catch (_) {
      // Proceed with the Energia page's own "--" fallback for every field.
    }
    try {
      final savedTemperatureEntities = await ref.read(savedTemperatureEntityConfigProvider.future);
      ref.read(temperatureEntityConfigProvider.notifier).state = savedTemperatureEntities;
    } catch (_) {
      // Proceed with the Temperatures sheet's own hardcoded/"--" defaults.
    }
    try {
      final savedCalendars = await ref.read(savedCalendarEntriesProvider.future);
      if (savedCalendars.isNotEmpty) {
        ref.read(calendarEntriesProvider.notifier).state = savedCalendars;
      }
    } catch (_) {
      // Proceed with no calendars configured — the card/sheet show an empty state.
    }
    try {
      final savedMass = await ref.read(savedMassConnectionConfigProvider.future);
      if (savedMass != null) {
        ref.read(massConnectionConfigProvider.notifier).state = savedMass;
      }
    } catch (_) {
      // Proceed with no Music Assistant server configured — the Music sheet shows an empty state.
    }
    try {
      final savedEvCars = await ref.read(savedEvCarsConfigProvider.future);
      if (!savedEvCars.isEmpty) {
        ref.read(evCarsConfigProvider.notifier).state = savedEvCars;
      }
    } catch (_) {
      // Proceed with the EV cards' own default names and "--" readings.
    }
    try {
      final savedIndividualSensors = await ref.read(savedIndividualSensorsProvider.future);
      // Same guard as the calendar list just above: an empty read (a fresh
      // browser profile with nothing saved yet) must not clobber whatever
      // individualSensorsProvider was set to at ProviderScope creation —
      // including a demo-mode override.
      if (savedIndividualSensors.isNotEmpty) {
        ref.read(individualSensorsProvider.notifier).state = savedIndividualSensors;
      }
    } catch (_) {
      // Proceed with the energy card's device slots left empty.
    }
    try {
      final savedRooms = await ref.read(savedRoomsProvider.future);
      // Same guard as calendars/individual sensors above.
      if (savedRooms.isNotEmpty) {
        ref.read(roomsProvider.notifier).state = savedRooms;
      }
    } catch (_) {
      // Proceed with the Divisões page's own empty state.
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
