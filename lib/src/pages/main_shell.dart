import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ev_cars_provider.dart';
import '../providers/ha_providers.dart';
import '../services/screen_power_controller.dart';
import '../sheets/sheet_registry.dart';
import '../theme/nocturne_theme.dart';
import 'climate_screen.dart';
import 'dashboard_screen.dart';
import '../sheets/dashboard/calendar_sheet.dart';
import '../sheets/dashboard/ev_sheet.dart';
import '../sheets/dashboard/music_sheet.dart';
import '../sheets/dashboard/temperature_sheet.dart';
import 'energy_screen.dart';
import 'rooms_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/shell/app_nav_bar.dart';

/// How long the screen has to stay off before the tab resets to Casa — long
/// enough that a screen-off/on that's really just someone briefly blocking
/// the panel doesn't visibly yank them back to Home mid-task.
const _resetToHomeAfterScreenOff = Duration(seconds: 5);

// Labels/icons follow the design reference's own nav set (Casa/Divisões/
// Energia/Aspirador/Automações) wherever a real screen actually matches —
// Casa, Divisões and Energia map directly onto Homepage/Rooms/Energy. The
// reference has no Climate or Settings equivalent (and this app has no
// vacuum or automations screen to put under "Aspirador"/"Automações"), so
// those two keep their own Portuguese labels in the same style rather than
// being mislabeled as functionality that isn't actually there.
const _navItems = [
  NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Casa'),
  NavItem(
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
    label: 'Divisões',
  ),
  NavItem(
    icon: Icons.thermostat_outlined,
    selectedIcon: Icons.thermostat,
    label: 'Clima',
  ),
  NavItem(
    icon: Icons.bolt_outlined,
    selectedIcon: Icons.bolt,
    label: 'Energia',
  ),
  NavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Definições',
  ),
];

const _screens = [
  DashboardScreen(),
  RoomsScreen(),
  ClimateScreen(),
  EnergyScreen(),
  SettingsScreen(),
];

/// Hosts the six tab screens behind a single floating bottom nav bar, with
/// a gradual fade where content scrolls underneath it. Tab content reserves
/// exactly [AppNavBar.floatingClearance] worth of bottom space (see
/// `DashboardScreen`) rather than a guessed round number, so the bar floats
/// with a precise, minimal gap instead of a wide dead strip. There's
/// exactly one [Scaffold] here; the tab screens are plain scrollable
/// bodies.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  Timer? _resetToHomeTimer;

  @override
  void initState() {
    super.initState();
    // Registered here (the one always-mounted widget with a stable root
    // context) rather than wherever each sheet's trigger card lives, so
    // opening a sheet by id — from an MQTT test command, say — works
    // regardless of which tab is currently showing.
    SheetRegistry.instance.register('temperatures', showTemperatureSheet);
    SheetRegistry.instance.register('calendar', showCalendarSheet);
    SheetRegistry.instance.register('music', showMusicSheet);
    SheetRegistry.instance.register(
      'ev-left',
      (context) => showEvSheet(context, CarSide.left),
    );
    SheetRegistry.instance.register(
      'ev-right',
      (context) => showEvSheet(context, CarSide.right),
    );
    SheetRegistry.instance.requestedId.addListener(_onSheetRequested);
    SheetRegistry.instance.closeRequests.addListener(_onCloseRequested);
    ScreenPowerController.instance.isOn.addListener(_onScreenPowerChanged);
  }

  @override
  void dispose() {
    SheetRegistry.instance.requestedId.removeListener(_onSheetRequested);
    SheetRegistry.instance.closeRequests.removeListener(_onCloseRequested);
    SheetRegistry.instance.unregister('temperatures');
    SheetRegistry.instance.unregister('calendar');
    SheetRegistry.instance.unregister('music');
    SheetRegistry.instance.unregister('ev-left');
    SheetRegistry.instance.unregister('ev-right');
    ScreenPowerController.instance.isOn.removeListener(_onScreenPowerChanged);
    _resetToHomeTimer?.cancel();
    super.dispose();
  }

  // Resets the selected tab back to Casa once the screen has been off for a
  // while — the change happens while nobody can see it either way, so
  // whoever wakes the panel next always lands on Home rather than wherever
  // the previous person left off (Settings, say). Cancels cleanly if the
  // screen comes back on before the delay elapses, so a quick off/on
  // doesn't reset anything.
  void _onScreenPowerChanged() {
    _resetToHomeTimer?.cancel();
    _resetToHomeTimer = null;
    if (ScreenPowerController.instance.isOn.value) return;
    _resetToHomeTimer = Timer(_resetToHomeAfterScreenOff, () {
      if (mounted && _selectedIndex != 0) setState(() => _selectedIndex = 0);
    });
  }

  void _onSheetRequested() {
    final id = SheetRegistry.instance.requestedId.value;
    if (id == null) return;
    SheetRegistry.instance.requestedId.value = null;
    SheetRegistry.instance.dispatch(context, id);
  }

  void _onCloseRequested() =>
      Navigator.of(context, rootNavigator: true).maybePop();

  @override
  Widget build(BuildContext context) {
    // Only the loading/error shape is used below (the `data` branch ignores
    // its payload), so selecting that down to a small record — rather than
    // watching the whole `AsyncValue` — means this shell (and everything
    // nested under it: nav bar, tab switcher) stops rebuilding on every
    // entity flush once the connection is up and steady.
    final loadState = ref.watch(
      entitiesProvider.select((async) => (isLoading: async.isLoading && !async.hasValue, error: async.hasError ? async.error : null)),
    );
    // Settings (rooms, EV cars, energy config, ...) load behind the same HA
    // connection — see `settingsHydrationProvider`. Every per-domain read in
    // there is independently try/caught, so this only ever reflects
    // `entitiesProvider.future` itself failing; the existing Retry button
    // below fixes both since it re-triggers that same future.
    final settingsLoadState = ref.watch(
      settingsHydrationProvider.select((async) => (isLoading: async.isLoading && !async.hasValue, error: async.hasError ? async.error : null)),
    );
    final isLoading = loadState.isLoading || settingsLoadState.isLoading;
    final error = loadState.error ?? settingsLoadState.error;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(entitiesProvider),
            )
          : Stack(
          children: [
            // Material's fade-through pattern for switching top-level
            // destinations. Trades away IndexedStack's state preservation
            // (each tab remounts fresh — scroll position etc. resets) for
            // the transition; that's the standard tradeoff of this pattern.
            PageTransitionSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (
                    child,
                    primaryAnimation,
                    secondaryAnimation,
                  ) => FadeThroughTransition(
                    animation: primaryAnimation,
                    secondaryAnimation: secondaryAnimation,
                    // FadeThroughTransition paints its own full-size background
                    // behind the incoming/outgoing child (defaulting to
                    // ThemeData.canvasColor) — pin it to match the scaffold
                    // instead of whatever that resolves to. Reads the token
                    // rather than hardcoding black: on the light theme the
                    // scaffold is `_Light.bg`, not black, and this fill sits
                    // behind every screen (including the gaps between cards),
                    // so a hardcoded black here painted the whole app's
                    // background wrong the moment the theme wasn't dark.
                    fillColor: NocturneColors.bg,
                    child: child,
                  ),
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: _screens[_selectedIndex],
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                // Fades content out just above the floating navbar so it
                // doesn't cut off abruptly — same reasoning as the
                // `fillColor` above: this needs to fade to the scaffold's
                // actual background, not a hardcoded black that only looked
                // right while the theme was always dark.
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [NocturneColors.bg.withValues(alpha: 0), NocturneColors.bg],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  // Margin on every side is what actually makes the bar
                  // float, rather than sit flush against the screen edges.
                  // Bottom margin here is exactly the 14 baked into
                  // AppNavBar.floatingClearance — keep the two in sync.
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: AppNavBar(
                    items: _navItems,
                    selectedIndex: _selectedIndex,
                    onSelect: (index) => setState(() => _selectedIndex = index),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load Home Assistant data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
