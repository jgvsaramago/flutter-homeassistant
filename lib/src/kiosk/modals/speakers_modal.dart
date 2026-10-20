import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/ma_models.dart';
import '../../music/music_store.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';
import '../widgets/music_widgets.dart';

Future<void> showSpeakers(BuildContext context) => showKModal(context, (_) => const SpeakersModal());

/// The design's "Colunas": which speakers this screen plays to. Tapping a
/// speaker groups it with the others (Music Assistant keeps them in sync),
/// each has its own volume, and the group has one too.
class SpeakersModal extends ConsumerWidget {
  const SpeakersModal({super.key});

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      KToast.show('$e'.replaceFirst('Bad state: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(musicStoreProvider);
    final speakers = m.speakers;
    final on = m.active;
    final onIds = on.map((p) => p.id).toSet();
    final others = m.others;
    final all = speakers.where((p) => p.available && (p.id == m.target?.id || m.canJoin(p))).map((p) => p.id).toList();
    final presets = [
      ('Toda a casa', KIcons.homeOutline, all),
      if (m.target != null) ('Só ${m.target!.name}', KIcons.volLow, [m.target!.id]),
    ];
    final brands = on.map((p) => p.provider).toSet();
    final summary = on.length > 1 ? '${on.length} colunas a tocar em sincronia' : 'A tocar só em ${on.isEmpty ? '—' : on.first.name}';

    return KModal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Colunas', style: KText.modalTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Toque numa coluna para a juntar ou tirar do grupo. A música continua sem parar.',
                      style: KText.s(20, color: KColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              KCircleButton(icon: KIcons.close, size: 64, iconSize: 26, stroke: 2.2, bg: KMusic.sand, border: null, onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
          if (!m.connected) ...[
            const SizedBox(height: 24),
            Text('Sem ligação ao Music Assistant.', style: KText.s(22, color: KColors.muted)),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Caption('TAMBÉM A TOCAR'),
            for (final o in others)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: KMusic.paper, borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      MaArt(image: o.queue.current?.image, label: o.queue.current?.name, size: 64, radius: 14),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.queue.current?.name ?? 'A tocar', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(22, weight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(o.player.name, style: KText.s(17, color: KColors.muted)),
                          ],
                        ),
                      ),
                      KButton(label: 'Controlar', height: 56, onTap: () => _run(() => m.setTarget(o.player.id))),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          _Caption('GRUPOS RÁPIDOS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in presets)
                MusicChip(
                  label: p.$1,
                  icon: p.$2,
                  on: p.$3.toSet().length == onIds.length && p.$3.toSet().containsAll(onIds),
                  onTap: () => _run(() => m.setGroup(p.$3)),
                ),
            ],
          ),
          if (on.length > 1) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              decoration: BoxDecoration(color: KMusic.paper, borderRadius: BorderRadius.circular(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Caption('VOLUME DO GRUPO')),
                      Text('${m.groupVolume}%', style: KText.s(20, weight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const KIcon(KIcons.volLow, size: 28, color: KColors.muted),
                      const SizedBox(width: 18),
                      Expanded(
                        child: KSlider(
                          value: m.groupVolume / 100,
                          height: 52,
                          trackHeight: 12,
                          knob: 36,
                          track: KMusic.line,
                          fill: KColors.accent,
                          onChanged: (_) {},
                          onEnd: (v) => _run(() => m.setGroupVolume((v * 100).round())),
                        ),
                      ),
                      const SizedBox(width: 18),
                      const KIcon(KIcons.volHigh, size: 28, color: KColors.muted),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Caption('COLUNAS DA CASA'),
          for (final p in speakers) Padding(padding: const EdgeInsets.only(top: 12), child: _SpeakerRow(player: p, store: m, run: _run)),
          if (brands.length > 1) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(22)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const KIcon(KIcons.info, size: 26, color: Color(0xFF7A4B00)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Colunas de sistemas diferentes tocam juntas num grupo do Music Assistant. Pode haver um pequeno atraso entre elas.',
                      style: KText.s(20, color: const Color(0xFF7A4B00), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: KMusic.rule, width: 1.5))),
            child: Row(
              children: [
                Expanded(child: Text(summary, style: KText.s(20, color: KColors.muted))),
                KButton.primary(label: 'Concluído', height: 72, padding: const EdgeInsets.symmetric(horizontal: 44), onTap: () => Navigator.of(context).maybePop()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: KText.s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1));
}

class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({required this.player, required this.store, required this.run});

  final MaPlayer player;
  final MusicStore store;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final on = store.active.any((p) => p.id == player.id);
    final group = store.active.length > 1;
    final avail = player.available;
    final q = store.queues[player.queueId];
    final busy = !on && q?.playing == true ? q?.current?.name : null;
    final joinable = on || player.id == store.target?.id || store.canJoin(player);
    final model = [player.manufacturer, player.model].where((s) => s.isNotEmpty).join(' ');
    final sub = !avail
        ? '${model.isEmpty ? 'Coluna' : model} · desligada'
        : busy != null
        ? '${model.isEmpty ? 'Coluna' : model} · a tocar $busy'
        : (!joinable ? '${model.isEmpty ? 'Coluna' : model} · não agrupa com ${store.target?.name ?? ''}' : model);
    final chip = on ? (group ? 'No grupo' : 'A tocar') : (busy != null ? 'Ocupada' : (avail ? 'Livre' : 'Indisponível'));
    return Opacity(
      opacity: avail ? 1 : 0.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: on ? KMusic.groupOn : KMusic.paper,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: on ? KColors.accent : Colors.transparent, width: 3),
        ),
        child: Column(
          children: [
            KPress(
              onTap: avail ? () => run(() => store.toggleSpeaker(player.id)) : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 90),
                padding: const EdgeInsets.fromLTRB(21, 13, 21, 13),
                color: Colors.transparent,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? KColors.accent : Colors.white,
                        border: Border.all(color: on ? KColors.accent : const Color(0xFFC9C4BA), width: 3),
                      ),
                      alignment: Alignment.center,
                      child: on ? const KIcon(KIcons.check, size: 24, color: Colors.white, stroke: 3) : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name, style: KText.s(24, weight: FontWeight.w600)),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.s(17, color: busy != null ? KColors.orangeInk : KColors.muted)),
                          ],
                        ],
                      ),
                    ),
                    if (on && store.queue?.playing == true) ...[const PlayingBars(height: 26, barWidth: 5, gap: 4), const SizedBox(width: 16)],
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? KColors.accent : (busy != null ? KColors.orangeTint : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(chip, style: KText.s(17, weight: FontWeight.w600, color: on ? Colors.white : (busy != null ? KColors.orangeInk : KColors.muted))),
                    ),
                  ],
                ),
              ),
            ),
            if (on && player.volume != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(85, 0, 21, 15),
                child: Row(
                  children: [
                    const KIcon(KIcons.volMid, size: 24, color: KColors.muted),
                    const SizedBox(width: 18),
                    Expanded(
                      child: KSlider(
                        value: player.volume! / 100,
                        track: const Color(0xFFD9E4E1),
                        fill: KColors.accent,
                        onChanged: (_) {},
                        onEnd: (v) => run(() => store.setVolume(player.id, (v * 100).round())),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text('${player.volume}%', textAlign: TextAlign.right, style: KText.s(20, weight: FontWeight.w600)),
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
