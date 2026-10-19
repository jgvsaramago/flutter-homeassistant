import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import '../data/house_models.dart';
import '../data/kiosk_entities.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'kiosk_widgets.dart';

/// The status pills beside the "Casa" title: locks, alarm (when there is
/// one) and how many lights are on.
class HouseStatusChips extends ConsumerWidget {
  const HouseStatusChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locks = ref.watch(locksProvider).where((l) => l.available).toList();
    final alarm = ref.watch(alarmProvider);
    final lights = ref.watch(lightsOnProvider);
    final open = locks.where((l) => !l.secured).length;

    Widget pill(String icon, String text, Color bg, Color fg) => Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locks.isNotEmpty)
          open == 0
              ? pill(KIcons.lock, 'Tudo trancado', KColors.greenTint, KColors.greenInk)
              : pill(KIcons.lockOpen, open == 1 ? '1 acesso aberto' : '$open acessos abertos', KColors.amberTint, KColors.amberInk),
        if (alarm != null) ...[
          const SizedBox(width: 12),
          switch (alarm.mode) {
            _ when alarm.triggered => pill(KIcons.shield, 'Alarme disparado', KColors.red, Colors.white),
            AlarmMode.off => pill(KIcons.shield, 'Alarme desligado', KColors.chip, KColors.ink2),
            AlarmMode.home => pill(KIcons.shield, 'Alarme em casa', KColors.blueTint, KColors.blue),
            AlarmMode.away => pill(KIcons.shield, 'Alarme ausente', KColors.redTint, KColors.redInk),
          },
        ],
        const SizedBox(width: 12),
        pill(KIcons.bulb, lights == 0 ? 'Luzes apagadas' : (lights == 1 ? '1 luz acesa' : '$lights luzes acesas'), KColors.amberTint, KColors.amberInk),
      ],
    );
  }
}

/// "Água quente": the hot-water tank's temperature against its target,
/// whether it's heating, and its power draw.
class WaterHeaterCard extends StatelessWidget {
  const WaterHeaterCard({super.key, required this.info});

  final WaterHeaterInfo info;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, dot) = switch (info.state) {
      'heating' => ('A aquecer', KColors.orangeTint, KColors.orangeInk, KColors.orange),
      'off' => ('Desligada', KColors.chipAlt, KColors.ink2, KColors.faint),
      _ => ('Pronta', KColors.greenTint, KColors.greenInk, KColors.green),
    };
    final fraction = info.temp != null && info.target != null && info.target! > 0 ? info.temp! / info.target! : 0.0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: KColors.sub, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Água quente', style: KText.s(24, weight: FontWeight.w600)),
              ),
              Container(
                height: 34,
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17)),
                child: Row(
                  children: [
                    KBlink(
                      enabled: info.state == 'heating',
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: KText.s(15, weight: FontWeight.w700, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Center(child: KIcon(KIcons.boiler, size: 32, color: KColors.ink2, stroke: 1.7)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: info.temp == null ? '--' : '${info.temp!.round()}',
                            children: [TextSpan(text: ' ºC', style: KText.d(24))],
                          ),
                          style: KText.d(44, height: 1),
                        ),
                        const Spacer(),
                        if (info.target != null) Text('Alvo ${info.target!.round()} ºC', style: KText.s(16, color: KColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    KProgress(
                      value: fraction,
                      height: 12,
                      track: KColors.border,
                      gradient: const LinearGradient(colors: [KColors.amber, KColors.orange]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(['Termoacumulador', if (info.powerKw != null) '${ptDec(info.powerKw!)} kW'].join(' · '), style: KText.s(15, color: KColors.muted)),
        ],
      ),
    );
  }
}

/// The gate camera tile that opens the intercom ("Ver e falar").
class GateCameraTile extends StatelessWidget {
  const GateCameraTile({super.key, required this.height, required this.onTap});

  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KPress(
      onTap: onTap,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: KColors.camera, borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KIcon(KIcons.video, size: 26, color: KColors.cameraText, stroke: 1.8),
                  const SizedBox(width: 10),
                  Text('Portão', style: KText.s(18, color: KColors.cameraText)),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                height: 44,
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    const KIcon(KIcons.phone, size: 22),
                    const SizedBox(width: 8),
                    Text('Ver e falar', style: KText.s(17, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Home Assistant camera as a still that refreshes every few seconds —
/// HA's `camera_proxy` snapshot, authorised by the token HA puts in the
/// entity's own `entity_picture`.
class HaCameraTile extends ConsumerStatefulWidget {
  const HaCameraTile({super.key, required this.entityId, required this.label, required this.height});

  final String entityId;
  final String label;
  final double height;

  @override
  ConsumerState<HaCameraTile> createState() => _HaCameraTileState();
}

class _HaCameraTileState extends ConsumerState<HaCameraTile> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(kioskEntitiesProvider.select((m) => m[widget.entityId]));
    final base = ref.watch(connectionConfigProvider)?.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final picture = e?.attributes['entity_picture'] as String?;
    final url = base == null || picture == null || e!.isUnavailable ? null : '$base$picture&_=$_tick';
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: KColors.camera, borderRadius: BorderRadius.circular(18)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(url, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink())
          else
            Center(
              child: Text('Câmara indisponível', style: KText.s(16, color: KColors.cameraText)),
            ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              widget.label,
              style: KText.s(15, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
