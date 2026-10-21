import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/weekly_forecast_provider.dart';
import '../data/casa_data.dart';
import '../data/house_config.dart';
import '../data/house_models.dart';
import '../data/pt_dates.dart';
import '../modals/camera_modal.dart';
import '../modals/climate_modal.dart';
import '../modals/energy_modal.dart';
import '../modals/intercom_modal.dart';
import '../modals/room_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/ac_widgets.dart';
import '../widgets/car_card.dart';
import '../widgets/energy_flow.dart';
import '../widgets/house_widgets.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> _try(Future<void> f) => f.catchError(KToast.error);

/// Casa: every room, energy, security, the weather station, climate and
/// the cars at home — white sections down a page that scrolls from under
/// the header to beneath the translucent nav bar.
class HousePage extends ConsumerWidget {
  const HousePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomTilesProvider).isNotEmpty;
    final energy = !ref.watch(energyInfoProvider.select((e) => e.isEmpty));
    final cars = ref.watch(carsProvider);

    // Built all at once (not a lazy ListView) so every block's staggered
    // fade-up starts on arrival, not when it's first scrolled into view.
    var block = 0;
    Widget up(Widget child) => Padding(
      padding: EdgeInsets.only(top: block == 0 ? 0 : 24),
      child: KFadeUp(index: block++, child: child),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 168),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                up(
                  Row(
                    children: [
                      Expanded(child: Text('Casa', style: KText.pageTitle)),
                      const _StatusPills(),
                    ],
                  ),
                ),
                if (rooms) up(const _RoomsSection()),
                if (energy) up(const _EnergySection()),
                up(const _SecuritySection()),
                up(
                  const IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ExteriorSection()),
                        SizedBox(width: 24),
                        Expanded(child: _ClimateSection()),
                      ],
                    ),
                  ),
                ),
                if (cars.isNotEmpty)
                  up(
                    Row(
                      children: [
                        for (final (i, c) in cars.indexed) ...[
                          if (i > 0) const SizedBox(width: 24),
                          Expanded(
                            child: KCarCard(car: c, background: Colors.white, radius: 36),
                          ),
                        ],
                        if (cars.length == 1) ...[const SizedBox(width: 24), const Spacer()],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The content fades out as it scrolls up under the header. A flat
        // gradient of the page colour rather than a mask: same look on the
        // plain background, without a full-page layer on the Pi.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 32,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KColors.page, Color(0x00F3F1EC)]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// White section card (radius 36, padding 28).
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
    child: child,
  );
}

Widget _title(String text, {String? sub}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(text, style: KText.cardTitle),
    if (sub != null && sub.isNotEmpty) ...[const SizedBox(height: 2), Text(sub, style: KText.s(17, color: KColors.muted))],
  ],
);

Widget _more(String label, VoidCallback onTap) => KButton(
  label: label,
  icon: KIcons.chevronRight,
  iconAfter: true,
  iconSize: 22,
  height: 56,
  fontSize: 20,
  gap: 6,
  bg: KColors.chip,
  border: null,
  padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
  onTap: onTap,
);

Widget _pill(String icon, String text, Color bg, Color fg) => Container(
  height: 52,
  padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      KIcon(icon, size: 24, color: fg),
      const SizedBox(width: 10),
      Text(
        text,
        style: KText.s(20, weight: FontWeight.w600, color: fg),
      ),
    ],
  ),
);

/// Beside the title: doors, windows and lights at a glance.
class _StatusPills extends ConsumerWidget {
  const _StatusPills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locks = ref.watch(locksProvider).where((l) => l.available).toList();
    final open = locks.where((l) => !l.secured).length;
    final windows = ref.watch(openWindowsProvider);
    final lights = ref.watch(lightsOnProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locks.isNotEmpty) ...[
          open == 0
              ? _pill(KIcons.lock, 'Portas fechadas', KColors.greenTint, KColors.greenInk)
              : _pill(KIcons.lockOpen, open == 1 ? '1 porta aberta' : '$open portas abertas', KColors.amberTint, KColors.amberInk),
          const SizedBox(width: 12),
        ],
        windows == 0
            ? _pill(KIcons.windowOpen, 'Janelas fechadas', Colors.white, KColors.ink2)
            : _pill(KIcons.windowOpen, windows == 1 ? '1 janela aberta' : '$windows janelas abertas', KColors.orangeTint, KColors.orangeInk),
        const SizedBox(width: 12),
        lights == 0
            ? _pill(KIcons.bulb, 'Luzes apagadas', Colors.white, KColors.ink2)
            : _pill(KIcons.bulb, lights == 1 ? '1 luz acesa' : '$lights luzes acesas', KColors.amberTint, KColors.amberInk),
      ],
    );
  }
}

// ─── Divisões ──────────────────────────────────────────────────────────

class _RoomsSection extends ConsumerWidget {
  const _RoomsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomTilesProvider);
    final anyOn = rooms.any((r) => r.lightOn) || ref.watch(lightsOnProvider) > 0;
    const legend = [
      (KIcons.bulb, 'Luzes'),
      (KIcons.window, 'Janela'),
      (KIcons.blinds, 'Estores'),
      (KIcons.acUnit, 'Ar condicionado'),
      (KIcons.fan, 'Ventilação'),
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Divisões', style: KText.cardTitle),
              const SizedBox(width: 20),
              Expanded(
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      for (final (i, (icon, label)) in legend.indexed) ...[
                        if (i > 0) const SizedBox(width: 18),
                        KIcon(icon, size: 20, color: KColors.muted),
                        const SizedBox(width: 6),
                        Text(label, style: KText.s(17, color: KColors.muted)),
                      ],
                    ],
                  ),
                ),
              ),
              KButton(
                label: 'Apagar todas as luzes',
                icon: KIcons.bulb,
                iconSize: 22,
                iconStroke: 2,
                height: 56,
                fontSize: 20,
                fg: anyOn ? KColors.ink : const Color(0xFFA3A7AE),
                padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                onTap: anyOn ? () => _try(allLightsOff(ref)) : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < rooms.length; i += 3) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                for (var j = i; j < i + 3; j++) ...[
                  if (j > i) const SizedBox(width: 12),
                  Expanded(child: j < rooms.length ? _RoomCard(room: rooms[j]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomCard extends ConsumerWidget {
  const _RoomCard({required this.room});

  final RoomTile room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = room;
    const off = Color(0xFFA3A7AE);
    final chips = <Widget>[
      if (r.light != null)
        _Chip(
          icon: KIcons.bulb,
          solid: r.lightOn,
          bg: r.lightOn ? const Color(0xFFFFE3A6) : Colors.white,
          fg: r.lightOn ? KColors.amberInk : off,
          label: r.lightOn ? '${r.lightsOn}' : null,
          onTap: () => _try(toggleLight(ref, r.light!.entityId, !r.lightOn)),
        ),
      if (r.window != null)
        _Chip(
          icon: r.windowOpen ? KIcons.windowOpen : KIcons.window,
          bg: r.windowOpen ? KColors.orangeTint : Colors.white,
          fg: r.windowOpen ? KColors.orange : off,
          label: r.windowOpen ? 'Aberta' : null,
        ),
      if (r.coverPosition case final pos?)
        _Chip(
          icon: pos == 0 ? KIcons.blindsClosed : KIcons.blinds,
          bg: pos > 0 ? KColors.blueTint : Colors.white,
          fg: pos > 0 ? KColors.blue : off,
          label: '$pos%',
        ),
      if (r.ac case final ac?)
        _Chip(
          icon: ac.on ? acModeIcon(ac.mode) : KIcons.acUnit,
          bg: ac.on ? ac.mode.tint : Colors.white,
          fg: ac.on ? ac.mode.color : off,
          label: ac.on ? ptDeg(ac.target) : null,
        ),
      if (r.vent != null)
        _Chip(icon: KIcons.fan, bg: r.ventOn ? KColors.greenTint : Colors.white, fg: r.ventOn ? KColors.greenInk : off, label: r.ventOn ? 'Ligada' : null),
    ];
    return KPress(
      onTap: () => showRoomModal(context, r.areaId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 140,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: r.lightOn ? KColors.lightRoomBg : KColors.sub, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.s(22, weight: FontWeight.w600),
                  ),
                ),
                if (r.temp != null) ...[const SizedBox(width: 10), Text(ptDeg(r.temp), style: KText.d(24))],
                if (r.humidity != null) ...[const SizedBox(width: 8), Text('${r.humidity!.round()}%', style: KText.s(15, color: KColors.muted))],
              ],
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final (i, c) in chips.indexed) ...[if (i > 0) const SizedBox(width: 8), c],
                  if (r.note != null)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: chips.isEmpty ? 0 : 12),
                        child: Text(
                          r.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.s(16, color: KColors.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A room's state icon: a 44 px circle, a pill with [label].
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.bg, required this.fg, this.label, this.solid = false, this.onTap});

  final String icon;
  final Color bg;
  final Color fg;
  final String? label;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 44,
      constraints: const BoxConstraints(minWidth: 44),
      padding: EdgeInsets.fromLTRB(label == null ? 0 : 10, 0, label == null ? 0 : 14, 0),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KIcon(icon, size: 22, color: fg, solid: solid),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: KText.s(16, weight: FontWeight.w700, color: fg),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? chip : KPress(onTap: onTap, child: chip);
  }
}

// ─── Energia ───────────────────────────────────────────────────────────

class _EnergySection extends ConsumerWidget {
  const _EnergySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(energyInfoProvider);
    final stats = ref.watch(energyStatsProvider).valueOrNull;
    final days = ref.watch(weeklyForecastProvider).valueOrNull;
    final now = DateTime.now();
    final t = stats?.today;
    final forecastToday = stats?.forecastFor(now);
    final forecastTomorrow = stats?.forecastFor(addDays(now, 1));
    const sun = Color(0xFFC98A2A);

    final tiles = t == null
        ? const <_EnergyTile>[]
        : [
            _EnergyTile(
              label: 'Solar',
              value: ptKwh(t.solar),
              unit: 'kWh',
              sub: forecastToday == null ? '' : 'De ${ptKwh(forecastToday)} kWh previstos',
              icon: KIcons.sunSmall,
              color: sun,
              bar: forecastToday == null || forecastToday <= 0 ? null : t.solar / forecastToday,
            ),
            _EnergyTile(
              label: 'Consumo',
              value: ptKwh(t.consumption),
              unit: 'kWh',
              sub: stats!.yesterdaySoFar == null ? '' : 'Ontem a esta hora: ${ptKwh(stats.yesterdaySoFar!.consumption)}',
              icon: KIcons.homeFlat,
              color: KColors.ink,
            ),
            _EnergyTile(
              label: 'Autoconsumo',
              value: t.selfUse == null ? '--' : '${(t.selfUse! * 100).round()}',
              unit: '%',
              sub: 'Do sol e da bateria',
              icon: KIcons.selfUse,
              color: const Color(0xFF2F9E68),
              bar: t.selfUse,
            ),
            _EnergyTile(
              label: 'Rede',
              value: ptKwh(t.gridIn),
              unit: 'kWh',
              sub: 'Importados · ${ptKwh(t.gridOut)} vendidos',
              icon: KIcons.pylon,
              color: const Color(0xFF2F7CC4),
            ),
          ];

    String? tomorrowSub;
    if (forecastTomorrow != null) {
      final sky = days != null && days.length > 1 ? weatherLabel(days[1].condition) : '';
      final diff = forecastToday == null || forecastToday <= 0 ? null : ((forecastTomorrow / forecastToday - 1) * 100).round();
      final compare = diff == null || diff == 0 ? null : '${diff < 0 ? 'menos' : 'mais'} ${diff.abs()}% do que hoje';
      tomorrowSub = [if (sky.isNotEmpty) sky, ?compare].join(' · ');
    }

    final flow = KEnergyFlow(info: info, consumers: true, label: 'AGORA', labelColor: KColors.muted, radius: 28);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _title('Energia', sub: energySummary(info, stats))),
              const SizedBox(width: 16),
              _more('Ver mais', () => showEnergyModal(context)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 440,
            child: tiles.isEmpty
                ? flow
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 680, child: flow),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                              child: Text('HOJE', style: KText.label),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final (i, row) in [tiles.sublist(0, 2), tiles.sublist(2)].indexed) ...[
                                    if (i > 0) const SizedBox(height: 12),
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(child: row[0]),
                                          const SizedBox(width: 12),
                                          Expanded(child: row[1]),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (forecastTomorrow != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                                child: Text('AMANHÃ', style: KText.label),
                              ),
                              Container(
                                height: 96,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(22)),
                                child: Row(
                                  children: [
                                    KIcon(
                                      days != null && days.length > 1 ? weatherIcon(days[1].condition) : KIcons.partlySun,
                                      size: 40,
                                      color: sun,
                                      stroke: 1.8,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Solar previsto', style: KText.s(20, weight: FontWeight.w600)),
                                          if (tomorrowSub != null && tomorrowSub.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              tomorrowSub,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: KText.s(15, color: KColors.amberInk),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        text: ptKwh(forecastTomorrow),
                                        children: [
                                          TextSpan(
                                            text: ' kWh',
                                            style: KText.s(17, weight: FontWeight.w600, color: KColors.muted),
                                          ),
                                        ],
                                      ),
                                      style: KText.d(32),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EnergyTile extends StatelessWidget {
  const _EnergyTile({required this.label, required this.value, required this.unit, required this.sub, required this.icon, required this.color, this.bar});

  final String label;
  final String value;
  final String unit;
  final String sub;
  final String icon;
  final Color color;
  final double? bar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(22)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KIcon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: KText.s(15, weight: FontWeight.w600, color: KColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: value,
            children: [
              TextSpan(
                text: ' $unit',
                style: KText.s(17, weight: FontWeight.w600, color: KColors.muted),
              ),
            ],
          ),
          style: KText.d(32, height: 1.1),
        ),
        if (bar != null) ...[const SizedBox(height: 6), KProgress(value: bar!, height: 6, track: const Color(0xFFE9E2D3), fill: color)],
        const SizedBox(height: 4),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KText.s(15, color: KColors.muted),
        ),
      ],
    ),
  );
}

// ─── Segurança ─────────────────────────────────────────────────────────

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locks = ref.watch(locksProvider);
    final lastOpened = ref.watch(lockLastOpenedProvider).valueOrNull ?? const <String, DateTime>{};
    final cameras = ref.watch(houseConfigProvider.select((c) => c.cameras)).take(3).toList();
    final open = locks.where((l) => l.available && !l.secured).length;
    final camRows = ((cameras.length + 1) / 2).ceil();
    final camsH = camRows * 176.0 + (camRows - 1) * 10;
    final locksH = locks.isEmpty ? 0.0 : locks.length * 112.0 + (locks.length - 1) * 10;
    final height = math.max(camsH, locksH);

    Widget camTile(int i) {
      if (i == 0) return GateCameraTile(height: 176, onTap: () => showIntercom(context));
      if (i > cameras.length) return const SizedBox.shrink();
      final c = cameras[i - 1];
      return KPress(
        onTap: () => showCameraModal(context, c.entityId),
        child: HaCameraTile(entityId: c.entityId, label: c.name.isEmpty ? c.entityId : c.name, height: 176, live: true),
      );
    }

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Segurança', style: KText.cardTitle),
              const SizedBox(width: 16),
              Text(
                locks.isEmpty ? locksSetupHint : (open == 0 ? 'Tudo fechado' : (open == 1 ? '1 aberta' : '$open abertas')),
                style: KText.s(17, color: KColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (locks.isNotEmpty) ...[
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        for (final (i, l) in locks.indexed) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Expanded(
                            child: _LockTile(lock: l, lastOpened: lastOpened[l.entityId]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      for (var row = 0; row < camRows; row++) ...[
                        if (row > 0) const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: camTile(row * 2)),
                            const SizedBox(width: 10),
                            Expanded(child: camTile(row * 2 + 1)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockTile extends StatelessWidget {
  const _LockTile({required this.lock, required this.lastOpened});

  final LockInfo lock;
  final DateTime? lastOpened;

  @override
  Widget build(BuildContext context) {
    final l = lock;
    final closed = l.secured || !l.available;
    // "Portão da garagem" is masculine, "Porta…" feminine; a lock is a door.
    final feminine = !l.isCover || l.name.toLowerCase().startsWith('porta');
    final state = !l.available
        ? 'Indisponível'
        : l.isCover
        ? (l.secured ? (feminine ? 'Fechada' : 'Fechado') : (feminine ? 'Aberta' : 'Aberto'))
        : l.stateLabel;
    final verb = l.isCover ? (feminine ? 'Aberta' : 'Aberto') : 'Destrancada';
    final last = !l.available
        ? ''
        : closed
        ? (lastOpened == null ? '' : '$verb pela última vez ${ptWhen(lastOpened!.toLocal())}')
        : '$verb desde ${lastOpened == null ? 'agora mesmo' : PtDates.hm(lastOpened!.toLocal())}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: KColors.sub,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: closed ? Colors.transparent : KColors.lightIconBg, width: 2),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: closed ? KColors.greenTint : KColors.amberTint, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: KIcon(
                l.kind == LockKind.garage ? KIcons.garageDoor : (l.isCover ? KIcons.door : KIcons.lock),
                size: 26,
                color: closed ? KColors.greenInk : KColors.amberInk,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.s(20, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: closed ? KColors.greenTint : KColors.amberTint, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        state,
                        style: KText.s(16, weight: FontWeight.w700, color: closed ? KColors.greenInk : KColors.orangeInk),
                      ),
                    ),
                  ],
                ),
                if (last.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    last,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KText.s(15, color: KColors.muted, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exterior ──────────────────────────────────────────────────────────

class _ExteriorSection extends ConsumerWidget {
  const _ExteriorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = ref.watch(exteriorProvider);
    final trendColor = switch (x.trendDir) {
      1 => KColors.orange,
      -1 => KColors.blue,
      _ => KColors.muted,
    };
    final range = [if (x.feels != null) 'Sensação ${x.feels!.round()}°', if (x.max != null && x.min != null) 'hoje máx. ${x.max}°, mín. ${x.min}°'].join(' · ');
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('Exterior', sub: x.period),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(x.temp == null ? '--' : ptDeg(x.temp), style: KText.d(80, weight: FontWeight.w400, height: 0.9, spacing: -2)),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (x.trend != null)
                      Row(
                        children: [
                          KIcon(x.trendDir > 0 ? KIcons.arrowUp : (x.trendDir < 0 ? KIcons.arrowDown : KIcons.minus), size: 18, color: trendColor, stroke: 2.4),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              x.trend!,
                              style: KText.s(18, weight: FontWeight.w600, color: trendColor),
                            ),
                          ),
                        ],
                      ),
                    if (range.isNotEmpty) ...[const SizedBox(height: 6), Text(PtDates.cap(range), style: KText.s(18, color: KColors.muted))],
                  ],
                ),
              ),
            ],
          ),
          if (x.tiles.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (var i = 0; i < x.tiles.length; i += 3) ...[
              if (i > 0) const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + 3; j++) ...[
                      if (j > i) const SizedBox(width: 10),
                      Expanded(child: j < x.tiles.length ? _ExteriorTileView(tile: x.tiles[j]) : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExteriorTileView extends StatelessWidget {
  const _ExteriorTileView({required this.tile});

  final ExteriorTile tile;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Transform.rotate(
              angle: tile.rotation * math.pi / 180,
              child: KIcon(tile.icon, size: 18, color: Color(tile.color)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tile.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.s(15, weight: FontWeight.w600, color: KColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: tile.value,
            children: [
              if (tile.unit.isNotEmpty)
                TextSpan(
                  text: ' ${tile.unit}',
                  style: KText.s(16, weight: FontWeight.w600, color: KColors.muted),
                ),
            ],
          ),
          maxLines: 1,
          style: KText.d(28, height: 1.1),
        ),
        if (tile.sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            tile.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.s(15, color: KColors.muted),
          ),
        ],
      ],
    ),
  );
}

// ─── Clima ─────────────────────────────────────────────────────────────

class _ClimateSection extends ConsumerWidget {
  const _ClimateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(acUnitsProvider);
    final on = units.where((u) => u.on).toList();
    final actions = ref.read(acActionsProvider);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  'Clima',
                  sub: units.isEmpty ? 'Sem ar condicionado' : (on.isEmpty ? 'Todos desligados' : '${on.length} de ${units.length} ligados'),
                ),
              ),
              const SizedBox(width: 12),
              _more('Ver todos', () => showClimateModal(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: on.isEmpty
                  ? SizedBox(
                      height: 52,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Nenhum ar condicionado ligado.', style: KText.s(18, color: KColors.muted)),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final u in on)
                          Container(
                            height: 52,
                            padding: const EdgeInsets.fromLTRB(12, 0, 18, 0),
                            decoration: BoxDecoration(color: u.mode.tint, borderRadius: BorderRadius.circular(26)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                KIcon(acModeIcon(u.mode), size: 22, color: u.mode.color),
                                const SizedBox(width: 10),
                                Text(
                                  u.name,
                                  style: KText.s(18, weight: FontWeight.w700, color: u.mode.color),
                                ),
                                const SizedBox(width: 10),
                                Text(ptDeg(u.target), style: KText.d(18, color: u.mode.color)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (units.isNotEmpty) ...[
            const SizedBox(height: 16),
            KPress(
              onTap: () => _try(on.isEmpty ? actions.allOn(units) : actions.allOff(units)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 72,
                decoration: BoxDecoration(color: on.isEmpty ? KColors.accent : KColors.chip, borderRadius: BorderRadius.circular(36)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KIcon(KIcons.power, size: 26, color: on.isEmpty ? Colors.white : KColors.ink, stroke: 2.2),
                    const SizedBox(width: 12),
                    Text(
                      on.isEmpty ? 'Ligar todos' : 'Desligar todos',
                      style: KText.s(22, weight: FontWeight.w600, color: on.isEmpty ? Colors.white : KColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
