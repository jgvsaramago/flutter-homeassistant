import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import '../../services/screen_power_controller.dart';
import '../data/house_models.dart';
import '../data/kiosk_entities.dart';
import '../data/pt_dates.dart';
import '../modals/intercom_modal.dart';
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
          Text(['Bomba de calor', if (info.powerKw != null) '${ptDec(info.powerKw!)} kW'].join(' · '), style: KText.s(15, color: KColors.muted)),
        ],
      ),
    );
  }
}

/// The building-door camera tile that opens the intercom ("Ver e falar").
///
/// Shows a still from the door camera, refreshed every 15 minutes — just
/// enough to see the tile is alive, without keeping a stream open. A failed
/// fetch retries after a minute; until the first still arrives (or with no
/// door station at all) it shows the plain icon and label.
class GateCameraTile extends ConsumerStatefulWidget {
  const GateCameraTile({super.key, required this.height, required this.onTap, this.compact = false});

  final double height;
  final VoidCallback onTap;

  /// The narrow Início tile (352 wide) rather than Casa's camera-grid one.
  final bool compact;

  @override
  ConsumerState<GateCameraTile> createState() => _GateCameraTileState();
}

class _GateCameraTileState extends ConsumerState<GateCameraTile> {
  static const _refreshEvery = Duration(minutes: 15);
  static const _retryAfter = Duration(minutes: 1);

  Timer? _timer;
  Uint8List? _still;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _timer?.cancel();
    final bytes = await ref.read(intercomControllerProvider).snapshot();
    if (!mounted) return;
    if (bytes != null && bytes.isNotEmpty) setState(() => _still = bytes);
    _timer = Timer(bytes != null ? _refreshEvery : _retryAfter, _refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(intercomControllerProvider).history;
    if (history == null) return _tile(0);
    return ValueListenableBuilder<int>(valueListenable: history.unseenMissed, builder: (context, missed, _) => _tile(missed));
  }

  Widget _tile(int missed) {
    final still = _still;
    final compact = widget.compact;
    final missedLabel = missed == 1 ? '1 chamada não atendida' : '$missed chamadas não atendidas';
    Widget pill(Widget icon, String label, Color fg) => Container(
      height: compact ? 44 : 48,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 0, compact ? 16 : 18, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(compact ? 22 : 24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: KText.s(compact ? 17 : 18, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
    final talk = pill(const KIcon(KIcons.phone, size: 20), 'Ver e falar', KColors.ink);
    final missedPill = pill(const KIcon(KIcons.phoneMissed, size: 18, color: KColors.red, stroke: 2.2), missedLabel, KColors.red);
    return KPress(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: KColors.camera, borderRadius: BorderRadius.circular(compact ? 20 : 22)),
        child: Stack(
          children: [
            if (still != null)
              Positioned.fill(
                child: LayoutBuilder(
                  // Decode at the tile's size, not the camera's 1080p.
                  builder: (context, c) =>
                      Image.memory(still, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()),
                ),
              )
            else
              const Center(child: KIcon(KIcons.video, size: 26, color: KColors.cameraText, stroke: 1.8)),
            // Início: the tile is narrow, so "Ver e falar" sits top-right and
            // missed calls take the "Porta do Prédio" label's place at the
            // bottom. Casa: one of the camera grid's tiles, ringed in the
            // accent, with an "Intercomunicador" tag (or the missed calls).
            if (compact) ...[
              Positioned(right: 12, top: 12, child: talk),
              if (missed > 0)
                Positioned(left: 12, bottom: 12, child: missedPill)
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    alignment: Alignment.bottomLeft,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x002C3036), Color(0xB317191C)]),
                    ),
                    child: Text(
                      'Porta do Prédio',
                      style: KText.s(17, weight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
            ] else ...[
              const CameraCaption(label: 'Porta do Prédio', icon: KIcons.phone),
              const Positioned(left: 10, top: 10, child: LiveBadge()),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                  decoration: BoxDecoration(color: missed > 0 ? Colors.white : KColors.accent, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KIcon(missed > 0 ? KIcons.phoneMissed : KIcons.phone, size: 16, color: missed > 0 ? KColors.red : Colors.white, stroke: 2.2),
                      const SizedBox(width: 6),
                      Text(
                        missed > 0 ? (missed == 1 ? '1 não atendida' : '$missed não atendidas') : 'Intercomunicador',
                        style: KText.s(15, weight: FontWeight.w700, color: missed > 0 ? KColors.red : Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: KColors.accent, width: 4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The red "AO VIVO" badge on a camera tile.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: KColors.red, borderRadius: BorderRadius.circular(14)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KBlink(
          period: const Duration(milliseconds: 1200),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'AO VIVO',
          style: KText.s(13, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );
}

/// A camera tile's name, bottom-left over a dark fade.
class CameraCaption extends StatelessWidget {
  const CameraCaption({super.key, required this.label, this.icon, this.size = 17});

  final String label;
  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      alignment: Alignment.bottomLeft,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0017191C), Color(0xBF17191C)]),
      ),
      child: Row(
        children: [
          if (icon != null) ...[KIcon(icon!, size: size - 1, color: Colors.white, stroke: 2.2), const SizedBox(width: 8)],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.s(size, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A Home Assistant camera as a still that refreshes every few seconds —
/// HA's `camera_proxy` snapshot, authorised by the token HA puts in the
/// entity's own `entity_picture`.
///
/// HA scales the snapshot down to the tile's width (`width=`) and it's
/// decoded at that size, rather than fetching and decoding a full-res
/// frame every 5 s for a 150 px tile; each superseded frame is evicted, or
/// the image cache would keep every one of them (each has a new URL).
class HaCameraTile extends ConsumerStatefulWidget {
  const HaCameraTile({
    super.key,
    required this.entityId,
    required this.label,
    required this.height,
    this.live = false,
    this.every = const Duration(seconds: 5),
    this.radius = 22,
    this.labelSize = 17,
    this.ring,
  });

  final String entityId;

  /// The name along the bottom; none for the camera modal's big view.
  final String? label;
  final double height;

  /// Shows the "AO VIVO" badge.
  final bool live;

  /// How often the still refreshes.
  final Duration every;
  final double radius;
  final double labelSize;

  /// A selection ring (the camera modal's strip).
  final Color? ring;

  @override
  ConsumerState<HaCameraTile> createState() => _HaCameraTileState();
}

class _HaCameraTileState extends ConsumerState<HaCameraTile> {
  Timer? _timer;
  int _tick = 0;
  ImageProvider? _shown;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      if (mounted && ScreenPowerController.instance.isOn.value) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shown?.evict();
    super.dispose();
  }

  ImageProvider _image(String url, int width) {
    final next = ResizeImage(NetworkImage(url), width: width);
    if (next != _shown) {
      // The previous frame stays on screen until this one arrives
      // (gaplessPlayback); dropping it from the cache doesn't affect that.
      _shown?.evict();
      _shown = next;
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(kioskEntitiesProvider.select((m) => m[widget.entityId]));
    final base = ref.watch(connectionConfigProvider)?.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final picture = e?.attributes['entity_picture'] as String?;
    final url = base == null || picture == null || e!.isUnavailable ? null : '$base$picture';
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: KColors.camera, borderRadius: BorderRadius.circular(widget.radius)),
      foregroundDecoration: widget.ring == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: widget.ring!, width: 3),
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
                return Image(
                  image: _image('$url&width=$w&_=$_tick', w),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                );
              },
            )
          else
            Center(
              child: Text('Câmara indisponível', style: KText.s(16, color: KColors.cameraText)),
            ),
          if (widget.label != null) CameraCaption(label: widget.label!, size: widget.labelSize),
          if (widget.live) const Positioned(left: 10, top: 10, child: LiveBadge()),
        ],
      ),
    );
  }
}
