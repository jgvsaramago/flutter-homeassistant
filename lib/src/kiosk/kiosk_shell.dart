import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ha_providers.dart';
import '../services/screen_power_controller.dart';
import '../services/voice_satellite.dart';
import '../sheets/sheet_registry.dart';
import 'data/calendar_data.dart';
import 'data/chores_data.dart';
import 'data/house_config.dart';
import 'data/kiosk_hydration.dart';
import 'data/meals_data.dart';
import 'data/settings_live_reload.dart';
import 'modals/assistant_modal.dart';
import 'pages/calendar_page.dart';
import 'pages/home_page.dart';
import 'pages/house_page.dart';
import 'pages/lists_page.dart';
import 'pages/meals_page.dart';
import 'pages/settings_page.dart';
import 'pages/tasks_page.dart';
import 'theme/kiosk_icons.dart';
import 'theme/kiosk_tokens.dart';
import 'widgets/kiosk_header.dart';
import 'widgets/kiosk_nav_bar.dart';
import 'widgets/kiosk_widgets.dart';

/// How long the screen has to stay off before the page resets to Início —
/// long enough that someone briefly blocking the panel isn't yanked back
/// home mid-task.
const _resetToHomeAfterScreenOff = Duration(seconds: 5);

/// The page the shell is showing. A provider (not shell-local state) so a
/// card on one page can send the person to another — Início's "Compras"
/// opening Listas, say.
final kioskPageProvider = StateProvider<KioskPage>((ref) => KioskPage.home);

/// The redesign's frame: header, the current page, the nav bar, and the
/// toast — on the fixed 1440×2560 canvas.
class KioskShell extends ConsumerStatefulWidget {
  const KioskShell({super.key});

  @override
  ConsumerState<KioskShell> createState() => _KioskShellState();
}

class _KioskShellState extends ConsumerState<KioskShell> {
  Timer? _resetToHomeTimer;
  Timer? _calendarRefresh;
  StreamSubscription<SatelliteEvent>? _voice;

  @override
  void initState() {
    super.initState();
    // MQTT "open sheet" commands from the old dashboard: the calendar one
    // still has a home here; the rest belonged to screens this design
    // folds into Casa.
    SheetRegistry.instance.register('calendar', (_) async => _go(KioskPage.calendar));
    SheetRegistry.instance.register('temperatures', (_) async => _go(KioskPage.house));
    SheetRegistry.instance.register('ev-left', (_) async => _go(KioskPage.house));
    SheetRegistry.instance.register('ev-right', (_) async => _go(KioskPage.house));
    SheetRegistry.instance.requestedId.addListener(_onSheetRequested);
    SheetRegistry.instance.closeRequests.addListener(_onCloseRequested);
    ScreenPowerController.instance.isOn.addListener(_onScreenPowerChanged);
    // Saying the wake word opens the Assistente so the conversation shows
    // on screen.
    VoiceSatellite.instance.start();
    _voice = VoiceSatellite.instance.events.listen((e) {
      if (e is SatelliteWake && mounted) showAssistant(context, byVoice: true);
    });
    // Calendars edited elsewhere (a phone, HA itself) show up within a few
    // minutes without anyone touching the panel.
    _calendarRefresh = Timer.periodic(const Duration(minutes: 5), (_) {
      if (ScreenPowerController.instance.isOn.value) ref.read(calendarRefreshProvider.notifier).state++;
    });
  }

  @override
  void dispose() {
    SheetRegistry.instance.requestedId.removeListener(_onSheetRequested);
    SheetRegistry.instance.closeRequests.removeListener(_onCloseRequested);
    for (final id in ['calendar', 'temperatures', 'ev-left', 'ev-right']) {
      SheetRegistry.instance.unregister(id);
    }
    ScreenPowerController.instance.isOn.removeListener(_onScreenPowerChanged);
    _resetToHomeTimer?.cancel();
    _calendarRefresh?.cancel();
    _voice?.cancel();
    super.dispose();
  }

  void _go(KioskPage page) {
    final current = ref.read(kioskPageProvider);
    if (current == page) return;
    // Meals and tasks are shared with other screens in the house; pick up
    // their edits whenever someone opens the page.
    if (page == KioskPage.meals || page == KioskPage.home) ref.read(mealPlanProvider.notifier).load().ignore();
    if (page == KioskPage.tasks || page == KioskPage.home) ref.read(choresProvider.notifier).load().ignore();
    // Same for the Casa mapping edited in HA's sidebar panel (locks, scenes…).
    if (page == KioskPage.house || page == KioskPage.home) {
      ref.read(houseConfigStoreProvider).read().then((c) {
        if (mounted) ref.read(houseConfigProvider.notifier).state = c;
      }).ignore();
    }
    ref.read(kioskPageProvider.notifier).state = page;
  }

  void _onScreenPowerChanged() {
    _resetToHomeTimer?.cancel();
    _resetToHomeTimer = null;
    if (ScreenPowerController.instance.isOn.value) {
      ref.read(calendarRefreshProvider.notifier).state++;
      return;
    }
    _resetToHomeTimer = Timer(_resetToHomeAfterScreenOff, () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      _go(KioskPage.home);
    });
  }

  void _onSheetRequested() {
    final id = SheetRegistry.instance.requestedId.value;
    if (id == null) return;
    SheetRegistry.instance.requestedId.value = null;
    SheetRegistry.instance.dispatch(context, id);
  }

  void _onCloseRequested() => Navigator.of(context, rootNavigator: true).maybePop();

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(kioskPageProvider);
    ref.watch(settingsLiveReloadProvider);
    final load = ref.watch(entitiesProvider.select((a) => (loading: a.isLoading && !a.hasValue, error: a.hasError ? a.error : null)));
    final settings = ref.watch(settingsHydrationProvider.select((a) => (loading: a.isLoading && !a.hasValue, error: a.hasError ? a.error : null)));
    final kiosk = ref.watch(kioskHydrationProvider.select((a) => a.isLoading && !a.hasValue));
    final loading = load.loading || settings.loading || kiosk;
    final error = load.error ?? settings.error;

    Widget body;
    if (loading) {
      body = const Center(
        child: SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 6, color: KColors.accent)),
      );
    } else if (error != null) {
      body = _ErrorView(message: error.toString(), onRetry: () => ref.invalidate(entitiesProvider));
    } else {
      body = _PageSwitcher(
        page: page,
        child: switch (page) {
          KioskPage.home => const HomePage(),
          KioskPage.calendar => const CalendarPage(),
          KioskPage.tasks => const TasksPage(),
          KioskPage.meals => const MealsPage(),
          KioskPage.lists => const ListsPage(),
          KioskPage.house => const HousePage(),
          KioskPage.settings => const SettingsPage(),
        },
      );
    }

    return Material(
      color: KColors.page,
      child: DefaultTextStyle(
        style: KText.s(20),
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 56, 56, 0),
                  child: KioskHeader(compact: page != KioskPage.home),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 56), child: body),
                ),
                const SizedBox(height: 32),
                KioskNavBar(selected: page, onSelect: _go, onAssistant: () => showAssistant(context)),
              ],
            ),
            const _ToastLayer(),
          ],
        ),
      ),
    );
  }
}

/// Swaps pages instantly: each page's sections run their own staggered
/// fade-up ([KFadeUp]) as they mount, so animating the page as a whole
/// here would double it up.
class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({required this.page, required this.child});

  final KioskPage page;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: ValueKey(page), child: child);
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KToastData?>(
      valueListenable: KToast.current,
      builder: (context, toast, _) => Positioned(
        left: 0,
        right: 0,
        bottom: 168,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            reverseDuration: const Duration(milliseconds: 220),
            switchInCurve: kEase,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: toast == null ? const SizedBox.shrink() : _Toast(key: ValueKey(toast), toast: toast),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.toast});

  final KToastData toast;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      constraints: const BoxConstraints(maxWidth: 1300),
      padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
      decoration: BoxDecoration(
        color: KColors.dark,
        borderRadius: BorderRadius.circular(46),
        boxShadow: const [BoxShadow(color: Color(0x4717191C), blurRadius: 40, offset: Offset(0, 16))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: toast.error ? KColors.red : KColors.green, shape: BoxShape.circle),
            child: KIcon(toast.error ? KIcons.close : KIcons.check, size: 28, color: Colors.white, stroke: 2.8),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              toast.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.s(22, weight: FontWeight.w500, color: Colors.white),
            ),
          ),
          const SizedBox(width: 18),
          KButton(
            label: toast.actionLabel,
            height: 64,
            fontSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 26),
            bg: const Color(0x29FFFFFF),
            fg: Colors.white,
            border: null,
            onTap: () {
              KToast.hide();
              toast.onAction?.call();
            },
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
      child: Container(
        width: 880,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KIcon(KIcons.refresh, size: 64, color: KColors.red, stroke: 2),
            const SizedBox(height: 24),
            Text('Sem ligação ao Home Assistant', style: KText.modalTitle),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KText.s(20, color: KColors.muted),
            ),
            const SizedBox(height: 32),
            KButton.primary(label: 'Tentar de novo', height: 72, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
