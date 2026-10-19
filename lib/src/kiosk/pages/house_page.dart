import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/house_config.dart';
import '../data/house_models.dart';
import '../modals/intercom_modal.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/ac_widgets.dart';
import '../widgets/car_card.dart';
import '../widgets/energy_flow.dart';
import '../widgets/house_widgets.dart';
import '../widgets/kiosk_widgets.dart';

Future<void> _try(Future<void> f) => f.catchError(KToast.error);

/// Casa: scenes, every room, climate, security, energy, cameras and cars.
class HousePage extends ConsumerWidget {
  const HousePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(scenesProvider);
    final active = ref.watch(activeSceneProvider);
    final rooms = ref.watch(roomTilesProvider);
    final units = ref.watch(acUnitsProvider);
    final energy = ref.watch(energyInfoProvider);
    final cars = ref.watch(evCarsProvider);
    final cameras = ref.watch(houseConfigProvider.select((c) => c.cameras));
    final outside = ref.watch(weatherNowProvider).temp;
    final acOn = units.where((u) => u.on).length;

    Widget heading(String text, {Widget? trailing}) => Row(
      children: [
        Expanded(
          child: Text(text, style: KText.s(26, weight: FontWeight.w600)),
        ),
        ?trailing,
      ],
    );

    return KSection(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            children: [
              Expanded(child: Text('Casa', style: KText.pageTitle)),
              const HouseStatusChips(),
            ],
          ),
          if (scenes.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                for (final (i, s) in scenes.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: KPress(
                      onTap: () => _try(runScene(ref, s)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 88,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: s.entityId == active ? KColors.accent : KColors.chip, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            KIcon(s.icon, size: 30, color: s.entityId == active ? Colors.white : KColors.ink, stroke: 1.9),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KText.s(22, weight: FontWeight.w600, color: s.entityId == active ? Colors.white : KColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (rooms.isNotEmpty) ...[
            const SizedBox(height: 22),
            heading(
              'Divisões',
              trailing: KButton(
                label: 'Apagar todas as luzes',
                icon: KIcons.bulb,
                iconSize: 22,
                iconStroke: 2,
                height: 56,
                fontSize: 19,
                padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                onTap: () => _try(allLightsOff(ref)),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 314 / 212,
              children: [for (final r in rooms) _RoomCard(room: r)],
            ),
          ],
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Clima', style: KText.s(26, weight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    acOn == 0 ? 'Todos desligados' : '$acOn de ${units.length} ligados',
                                    if (outside != null) 'Exterior ${outside.round()}°',
                                  ].join(' · '),
                                  style: KText.s(17, color: KColors.muted),
                                ),
                              ],
                            ),
                          ),
                          if (acOn > 0)
                            KButton(
                              label: 'Desligar todos',
                              icon: KIcons.power,
                              iconSize: 20,
                              height: 52,
                              fontSize: 17,
                              gap: 8,
                              border: null,
                              padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                              onTap: () => _try(ref.read(acActionsProvider).allOff(units)),
                            ),
                        ],
                      ),
                      for (final u in units) ...[const SizedBox(height: 14), KAcRow(unit: u)],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: _SecurityCard()),
            ],
          ),
          if (!energy.isEmpty) ...[const SizedBox(height: 22), SizedBox(height: 456, child: KEnergyFlow(info: energy, consumers: true))],
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Câmaras', style: KText.s(24, weight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GateCameraTile(height: 260, onTap: () => showIntercom(context)),
                      if (cameras.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 290 / 150,
                          children: [for (final c in cameras) HaCameraTile(entityId: c.entityId, label: c.name.isEmpty ? c.entityId : c.name, height: 150)],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Carros', style: KText.s(24, weight: FontWeight.w600)),
                      for (final c in cars) ...[const SizedBox(height: 16), KCarCard(car: c)],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final on = room.lightOn;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: on ? KColors.lightRoomBg : KColors.sub, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  room.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KText.s(21, weight: FontWeight.w600, height: 1.15),
                ),
              ),
              if (room.temp != null) Text('${room.temp!.toStringAsFixed(1).replaceAll('.', ',')}°', style: KText.d(22)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in room.info)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: i.dot, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              i.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.s(16, color: KColors.ink3),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (room.lightId != null)
            KPress(
              onTap: () => _try(toggleLight(ref, room.lightId!, !on)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 56,
                padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                decoration: BoxDecoration(color: on ? KColors.lightBtnBg : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: on ? KColors.lightIconBg : KColors.chipAlt, shape: BoxShape.circle),
                      child: Center(child: KIcon(KIcons.bulb, size: 22, color: on ? KColors.lightIconFg : KColors.muted)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        room.lightLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.s(17, weight: FontWeight.w600),
                      ),
                    ),
                    KSwitch(on: on, small: true, onColor: KColors.ink),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarm = ref.watch(alarmProvider);
    final locks = ref.watch(locksProvider);
    final sensors = ref.watch(securitySensorsProvider);
    Widget label(String t) => Text(
      t,
      style: KText.s(17, weight: FontWeight.w700, color: KColors.muted, spacing: 1),
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Segurança', style: KText.s(26, weight: FontWeight.w600)),
          if (alarm != null) ...[
            const SizedBox(height: 16),
            label('ALARME'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Row(
                children: [
                  for (final (i, (mode, title, sub, color)) in const [
                    (AlarmMode.off, 'Desarmado', 'Sem vigilância', KColors.muted),
                    (AlarmMode.home, 'Em casa', 'Só exterior', KColors.blue),
                    (AlarmMode.away, 'Ausente', 'Casa toda', KColors.red),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: KPress(
                        onTap: alarm.mode == mode ? null : () => _try(setAlarmMode(ref, alarm, mode)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 72,
                          decoration: BoxDecoration(color: alarm.mode == mode ? color : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: KText.s(19, weight: FontWeight.w700, color: alarm.mode == mode ? Colors.white : KColors.ink),
                              ),
                              Text(
                                sub,
                                style: KText.s(14, weight: FontWeight.w500, color: alarm.mode == mode ? const Color(0xD9FFFFFF) : KColors.ink2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          label('FECHADURAS E PORTÕES'),
          if (locks.isEmpty) ...[const SizedBox(height: 10), Text(locksSetupHint, style: KText.s(17, color: KColors.muted))],
          if (locks.isNotEmpty) ...[
            for (final l in locks) ...[
              const SizedBox(height: 10),
              Container(
                height: 80,
                padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: l.secured ? KColors.greenTint : KColors.amberTint, borderRadius: BorderRadius.circular(14)),
                      child: Center(child: KIcon(l.secured ? KIcons.lock : KIcons.lockOpen, size: 24, color: l.secured ? KColors.greenInk : KColors.amberInk)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KText.s(20, weight: FontWeight.w600),
                          ),
                          Text(
                            l.stateLabel,
                            style: KText.s(16, weight: FontWeight.w600, color: l.secured ? KColors.greenInk : KColors.orangeInk),
                          ),
                        ],
                      ),
                    ),
                    if (l.available)
                      KButton(
                        label: l.actionLabel,
                        height: 56,
                        fontSize: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        onTap: () => _try(ref.read(lockActionsProvider).toggle(l)),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (sensors.isNotEmpty) ...[
            const SizedBox(height: 16),
            label('SENSORES'),
            for (final s in sensors) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.text, style: KText.s(17, color: KColors.ink2)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
