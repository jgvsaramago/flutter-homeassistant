import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/ma_models.dart';
import '../../music/music_store.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';
import '../widgets/music_widgets.dart';
import '../modals/speakers_modal.dart';
import 'music_page.dart';

Future<void> _run(Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    KToast.show('$e'.replaceFirst('Bad state: ', ''), error: true);
  }
}

/// Ticks once a second while something plays, so the position moves.
mixin _Ticking<T extends StatefulWidget> on State<T> {
  Timer? _tick;

  void tickWhile(bool playing) {
    if (playing && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!playing && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

final _favOverride = <String, bool>{};

bool _isFav(MaItem? item) => item != null && (_favOverride[item.uri] ?? item.favorite);

Future<void> _toggleFav(MusicStore m, MaItem? item, VoidCallback changed) async {
  if (item == null) return;
  final on = !_isFav(item);
  _favOverride[item.uri] = on;
  changed();
  try {
    await m.setFavorite(item, on);
  } catch (_) {
    _favOverride[item.uri] = !on;
    changed();
    KToast.show('Não foi possível guardar', error: true);
  }
}

/// The design's "A tocar": the whole music card, big cover (or the queue),
/// transport, position, the speakers and their volume.
class NowPlayingView extends ConsumerStatefulWidget {
  const NowPlayingView({super.key, required this.onClose, required this.onOpenContext, this.onCovered});

  final VoidCallback onClose;
  final ValueChanged<MaItem> onOpenContext;

  /// True once the view has slid all the way in and hides the page behind
  /// it, false as it starts to leave — so that page can stop painting.
  final ValueChanged<bool>? onCovered;

  @override
  ConsumerState<NowPlayingView> createState() => _NowPlayingViewState();
}

class _NowPlayingViewState extends ConsumerState<NowPlayingView> with _Ticking, SingleTickerProviderStateMixin {
  bool _queue = false;
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _enter.forward().then((_) {
      if (mounted) widget.onCovered?.call(true);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    // Bring the page back first and let it paint before moving: redrawing
    // the whole page in the slide's first frame made the close stutter.
    widget.onCovered?.call(false);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _enter.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.easeIn);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(musicStoreProvider);
    final q = m.queue;
    final cur = q?.current;
    final media = cur?.media;
    tickWhile(q?.playing == true);
    final now = DateTime.now();
    final dur = cur?.duration ?? 0;
    final pos = q?.position(now) ?? 0;
    final live = dur <= 0;
    final ctx = m.context;
    final tint = KMusic.gradientFor(media?.uri ?? cur?.name ?? '').colors.last;
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) => FractionalTranslation(translation: Offset(0, 1 - kEase.transform(_enter.value)), child: child),
      // Its own layer: the slide only moves it, rather than repainting the
      // whole view (and the page under it) every frame.
      child: RepaintBoundary(
        child: Container(
        decoration: BoxDecoration(
          // Opaque: the cover's tone laid over white, so the page behind
          // doesn't show through.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.alphaBlend(tint.withValues(alpha: .2), Colors.white), Colors.white],
            stops: const [0, .46],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(36, 28, 36, 40),
        child: Column(
          children: [
            Row(
              children: [
                _GlassButton(icon: KIcons.chevronDown, onTap: _close),
                Expanded(
                  child: Column(
                    children: [
                      Text(ctx?.kind ?? 'A TOCAR EM ${m.targetLabel.toUpperCase()}', style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1)),
                      const SizedBox(height: 4),
                      Text(ctx?.title ?? m.targetLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(22, weight: FontWeight.w600)),
                    ],
                  ),
                ),
                _GlassButton(
                  icon: KIcons.dots,
                  stroke: 3,
                  onTap: ctx?.item == null || ctx!.item!.mediaType == 'radio' ? null : () => widget.onOpenContext(ctx.item!),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _queue
                    ? _QueuePanel(store: m)
                    : AnimatedScale(
                        scale: q?.playing == true ? 1 : 0.92,
                        duration: const Duration(milliseconds: 500),
                        curve: kEase,
                        child: MaArt(
                          key: ValueKey(media?.uri ?? cur?.name),
                          image: cur?.image,
                          item: media,
                          label: media?.albumName ?? cur?.name,
                          size: 880,
                          radius: 36,
                          labelSize: 84,
                          shadow: true,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cur?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.d(46, height: 1.1, spacing: -0.5)),
                        const SizedBox(height: 8),
                        Text(
                          [if (media?.artistNames.isNotEmpty == true) media!.artistNames, if (media?.albumName != null) media!.albumName!].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.s(26, color: KColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  _GlassButton(
                    icon: KIcons.heart,
                    size: 72,
                    iconSize: 34,
                    filled: _isFav(media),
                    fg: _isFav(media) ? const Color(0xFFE5484D) : KColors.ink,
                    onTap: media == null ? null : () => _toggleFav(m, media, () => setState(() {})),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: live
                  ? SizedBox(
                      height: 76,
                      child: Row(
                        children: [
                          KBlink(
                            period: const Duration(milliseconds: 1400),
                            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 12),
                          Text('EM DIRETO', style: KText.s(20, weight: FontWeight.w700, color: KColors.red, spacing: 1)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        KSlider(
                          value: dur == 0 ? 0 : pos / dur,
                          trackHeight: 12,
                          knob: 32,
                          knobColor: KColors.ink,
                          knobShadow: false,
                          onChanged: (_) {},
                          onEnd: (v) => _run(() => m.seek((v * dur).round())),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDuration(pos).isEmpty ? '0:00' : fmtDuration(pos), style: KText.s(20, color: KColors.muted)),
                            Text('-${fmtDuration(dur - pos).isEmpty ? '0:00' : fmtDuration(dur - pos)}', style: KText.s(20, color: KColors.muted)),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MusicRoundButton(
                  icon: KIcons.shuffle,
                  size: 80,
                  iconSize: 34,
                  bg: q?.shuffle == true ? KColors.accent : Colors.transparent,
                  fg: q?.shuffle == true ? Colors.white : KColors.ink,
                  onTap: () => _run(() => m.setShuffle(!(q?.shuffle ?? false))),
                ),
                const SizedBox(width: 40),
                MusicRoundButton(icon: KIcons.prevFilled, size: 96, iconSize: 52, bg: Colors.transparent, filled: true, onTap: () => _run(m.previous)),
                const SizedBox(width: 40),
                KPress(
                  onTap: () => _run(m.playPause),
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: const BoxDecoration(
                      color: KColors.ink,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x4D17191C), blurRadius: 34, offset: Offset(0, 14))],
                    ),
                    alignment: Alignment.center,
                    child: KIcon(q?.playing == true ? KIcons.pauseFilled : KIcons.playFilled, size: 60, color: Colors.white, filled: true),
                  ),
                ),
                const SizedBox(width: 40),
                MusicRoundButton(icon: KIcons.nextFilled, size: 96, iconSize: 52, bg: Colors.transparent, filled: true, onTap: () => _run(m.next)),
                const SizedBox(width: 40),
                Stack(
                  children: [
                    MusicRoundButton(
                      icon: KIcons.repeat,
                      size: 80,
                      iconSize: 34,
                      bg: q?.repeat != 'off' && q != null ? KColors.accent : Colors.transparent,
                      fg: q?.repeat != 'off' && q != null ? Colors.white : KColors.ink,
                      onTap: () => _run(m.cycleRepeat),
                    ),
                    if (q?.repeat == 'one')
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IgnorePointer(
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Text('1', style: KText.s(14, weight: FontWeight.w700, color: KColors.accent)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  SpeakersButton(label: m.targetLabel, count: m.active.length, dark: true, height: 72),
                  const SizedBox(width: 20),
                  const KIcon(KIcons.volLow, size: 28, color: KColors.muted),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KSlider(
                      value: m.groupVolume / 100,
                      onChanged: (_) {},
                      onEnd: (v) => _run(() => m.setGroupVolume((v * 100).round())),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const KIcon(KIcons.volHigh, size: 28, color: KColors.muted),
                  const SizedBox(width: 20),
                  KPress(
                    onTap: () => setState(() => _queue = !_queue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 72,
                      padding: const EdgeInsets.fromLTRB(20, 0, 26, 0),
                      decoration: BoxDecoration(color: _queue ? KColors.accent : const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(36)),
                      child: Row(
                        children: [
                          KIcon(KIcons.queue, size: 30, color: _queue ? Colors.white : KColors.ink),
                          const SizedBox(width: 12),
                          Text('Fila', style: KText.s(22, weight: FontWeight.w600, color: _queue ? Colors.white : KColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, this.onTap, this.size = 64, this.iconSize = 30, this.filled = false, this.fg = KColors.ink, this.stroke = 2.2});

  final String icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final bool filled;
  final Color fg;
  final double stroke;

  @override
  Widget build(BuildContext context) => MusicRoundButton(icon: icon, onTap: onTap, size: size, iconSize: iconSize, bg: const Color(0xB3FFFFFF), fg: fg, filled: filled, stroke: stroke);
}

/// What's coming up, in the cover's place.
class _QueuePanel extends StatefulWidget {
  const _QueuePanel({required this.store});

  final MusicStore store;

  @override
  State<_QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<_QueuePanel> {
  Future<List<MaQueueItem>>? _items;
  Object? _key;

  /// Removed here and not yet gone from MA's queue — hidden at once, back
  /// if MA refuses.
  final _hidden = <String>{};

  Future<void> _hide(Iterable<String> ids, Future<void> Function() remove) async {
    final these = ids.toSet();
    setState(() => _hidden.addAll(these));
    try {
      await remove();
    } catch (e) {
      if (mounted) setState(() => _hidden.removeAll(these));
      KToast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.store;
    final cur = m.queue?.current;
    final key = (m.queueItemsVersion, cur?.queueItemId, m.queue?.id);
    if (key != _key) {
      _key = key;
      _items = m.upcoming();
    }
    return Container(
      height: 880,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(36)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A TOCAR EM ${m.targetLabel.toUpperCase()}', style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KMusic.groupOn, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                MaArt(image: cur?.image, item: cur?.media, label: cur?.name, size: 80, radius: 14),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cur?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(24, weight: FontWeight.w600, color: KColors.accent)),
                      const SizedBox(height: 4),
                      Text(cur?.media?.artistNames ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(17, color: KColors.muted)),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.only(right: 10), child: PlayingBars(playing: m.queue?.playing == true, height: 26, barWidth: 5, gap: 4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<MaQueueItem>>(
            future: _items,
            builder: (context, snap) {
              final items = (snap.data ?? const <MaQueueItem>[]).where((i) => !_hidden.contains(i.queueItemId)).toList();
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'A SEGUIR · ${items.length} ${items.length == 1 ? 'faixa' : 'faixas'}',
                            style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1),
                          ),
                        ),
                        if (items.isNotEmpty) KButton(label: 'Limpar fila', height: 52, onTap: () => _hide(items.map((i) => i.queueItemId), m.clearUpcoming)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: !snap.hasData
                          ? const Center(child: CircularProgressIndicator(color: KColors.accent))
                          : items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'A fila está vazia. Toque em "Adicionar à fila" numa playlist ou álbum.',
                                textAlign: TextAlign.center,
                                style: KText.s(20, color: KColors.muted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 4),
                              itemBuilder: (_, i) {
                                final it = items[i];
                                return Container(
                                  constraints: const BoxConstraints(minHeight: 84),
                                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                                  child: Row(
                                    children: [
                                      const KIcon(KIcons.drag, size: 24, color: KMusic.faint),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: KPress(
                                          onTap: () => _run(() => m.playQueueItem(it)),
                                          child: Row(
                                            children: [
                                              MaArt(image: it.image, item: it.media, label: it.name, size: 60, radius: 12),
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(22, weight: FontWeight.w600)),
                                                    const SizedBox(height: 3),
                                                    Text(it.media?.artistNames ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(17, color: KColors.muted)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Text(fmtDuration(it.duration), style: KText.s(20, color: KColors.muted)),
                                      KCircleButton(
                                        icon: KIcons.close,
                                        size: 56,
                                        iconSize: 24,
                                        stroke: 2.2,
                                        bg: Colors.transparent,
                                        fg: KColors.muted,
                                        border: null,
                                        onTap: () => _hide([it.queueItemId], () => m.removeQueueItem(it.queueItemId)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The persistent player under the music card.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> with _Ticking {
  /// The track whose "A tocar" cover is already decoded.
  String? _warmed;

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(musicStoreProvider);
    final q = m.queue;
    final cur = q?.current;
    final media = cur?.media;
    tickWhile(q?.playing == true);
    final track = media?.uri ?? cur?.name;
    if (track != _warmed) {
      _warmed = track;
      final image = cur?.image ?? media?.image;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) precacheMaArt(context, ref, image, 880);
      });
    }
    final dur = cur?.duration ?? 0;
    final pct = dur > 0 ? (q!.position(DateTime.now()) / dur).clamp(0.0, 1.0) : (cur == null ? 0.0 : 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: kEase,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child)),
      child: Container(
        height: 128,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: KPress(
                      onTap: widget.onOpen,
                      child: Row(
                        children: [
                          MaArt(image: cur?.image, item: media, label: media?.albumName ?? cur?.name, size: 88, radius: 16, shadow: true),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cur?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(24, weight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(media?.artistNames ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(20, color: KColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  MusicRoundButton(
                    icon: KIcons.heart,
                    size: 64,
                    bg: Colors.transparent,
                    filled: _isFav(media),
                    fg: _isFav(media) ? const Color(0xFFE5484D) : KColors.ink,
                    onTap: media == null ? null : () => _toggleFav(m, media, () => setState(() {})),
                  ),
                  const SizedBox(width: 16),
                  MusicRoundButton(icon: KIcons.prevFilled, size: 64, iconSize: 34, bg: Colors.transparent, filled: true, onTap: () => _run(m.previous)),
                  const SizedBox(width: 16),
                  KPress(
                    onTap: () => _run(m.playPause),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(color: KColors.accent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: KIcon(q?.playing == true ? KIcons.pauseFilled : KIcons.playFilled, size: 36, color: Colors.white, filled: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  MusicRoundButton(icon: KIcons.nextFilled, size: 64, iconSize: 34, bg: Colors.transparent, filled: true, onTap: () => _run(m.next)),
                  const SizedBox(width: 20),
                  Container(width: 1.5, height: 56, color: KColors.navBorder),
                  const SizedBox(width: 20),
                  _MiniSpeakers(label: m.targetLabel),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 5,
                color: KMusic.rule,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: pct, child: Container(color: KColors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSpeakers extends StatelessWidget {
  const _MiniSpeakers({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return KPress(
      onTap: () => showSpeakers(context),
      child: Container(
        height: 64,
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
        decoration: BoxDecoration(color: KMusic.sand, borderRadius: BorderRadius.circular(32)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KIcon(KIcons.speaker, size: 26, color: KColors.accent, stroke: 1.9),
            const SizedBox(width: 10),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(20, weight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
