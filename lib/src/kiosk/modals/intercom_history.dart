import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/doorbell_history.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

const _subtle = Color(0xFFB9BEC4);
const _faint = Color(0xFF9AA0A6);
const _rowBg = Color(0xFF22252A);
const _newRed = Color(0xFFE5484D);
const _doorFg = Color(0xFF8BE0A4);
const _doorTint = Color.fromRGBO(111, 207, 138, 0.16);

/// How a call ended, as the design's history shows it.
class _Outcome {
  const _Outcome(this.label, this.fg, this.tint, this.icon, this.sub);

  final String label;
  final Color fg;
  final Color tint;
  final String icon;
  final String sub;

  static const indoor = _Outcome(
    'Atendida no intercomunicador',
    Color(0xFF8BE0A4),
    Color.fromRGBO(111, 207, 138, 0.16),
    KIcons.phone,
    'Falaram pelo intercomunicador interior.',
  );
  // This screen has no microphone yet: answering here only listens.
  static const here = _Outcome('Atendida neste ecrã', Color(0xFF9CC3F5), Color.fromRGBO(138, 180, 248, 0.16), KIcons.phone, 'Ouviram a porta por este ecrã.');
  static const missed = _Outcome(
    'Não atendida',
    Color(0xFFFF8A80),
    Color.fromRGBO(255, 138, 128, 0.16),
    KIcons.phoneMissed,
    'Ninguém atendeu, aqui nem no intercomunicador.',
  );
  static const ringing = _Outcome('A tocar agora', Color(0xFFF7B267), Color.fromRGBO(247, 178, 103, 0.18), KIcons.bell, 'Ainda pode atender no intercomunicador.');

  static _Outcome of(DoorbellCall c) => c.ringing
      ? ringing
      : c.answeredIndoor
      ? indoor
      : c.answeredHere
      ? here
      : missed;
}

/// "Hoje · 14:32", "Ontem · 09:10", "Ter, 14 out · 18:05" (+ the year when
/// it isn't this one).
String _when(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  final hm = PtDates.hm(d);
  if (days == 0) return 'Hoje · $hm';
  if (days == 1) return 'Ontem · $hm';
  return '${PtDates.abbrTitle[d.weekday - 1]}, ${PtDates.short(d)}${d.year != now.year ? ' ${d.year}' : ''} · $hm';
}

String _talk(Duration d) => '${d.inMinutes}:${PtDates.two(d.inSeconds % 60)}';

/// The history list, in the intercom card's camera slot: newest first, a
/// month divider only where the month changes, the calls that were new on
/// opening tagged «NOVA».
class IntercomHistoryList extends StatelessWidget {
  const IntercomHistoryList({
    super.key,
    required this.history,
    required this.newIds,
    required this.pictures,
    required this.controller,
    required this.onPick,
    required this.onRinging,
  });

  final DoorbellHistory history;
  final Set<String> newIds;
  final Future<Uint8List?> Function(DoorbellCall) pictures;
  final ScrollController controller;
  final ValueChanged<int> onPick;

  /// A call that's still ringing opens the live view instead of a picture.
  final VoidCallback onRinging;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DoorbellCall>>(
      valueListenable: history.calls,
      builder: (context, calls, _) {
        if (calls.isEmpty) return const _Empty();
        final now = DateTime.now();
        final missed = calls.where((c) => c.missed).length;
        final items = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '${calls.length} ${calls.length == 1 ? 'chamada' : 'chamadas'}'
                    '${missed > 0 ? ' · $missed ${missed == 1 ? 'não atendida' : 'não atendidas'}' : ''}',
                    style: KText.s(20, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                Text('Mais recentes primeiro', style: KText.s(17, color: _faint)),
              ],
            ),
          ),
        ];
        var month = (now.year, now.month);
        for (final (i, c) in calls.indexed) {
          if ((c.at.year, c.at.month) != month) {
            month = (c.at.year, c.at.month);
            items.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
                child: Text(
                  '${PtDates.months[c.at.month - 1].toUpperCase()}${c.at.year != now.year ? ' ${c.at.year}' : ''}',
                  style: KText.s(15, weight: FontWeight.w700, color: _faint).copyWith(letterSpacing: 1),
                ),
              ),
            );
          }
          items.add(_Row(call: c, isNew: newIds.contains(c.id), picture: pictures(c), onTap: c.ringing ? onRinging : () => onPick(i)));
        }
        if (calls.length > 12) {
          items.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
              child: Text(
                'Fim da lista. Este ecrã guarda as últimas 200 chamadas.',
                textAlign: TextAlign.center,
                style: KText.s(17, color: _faint),
              ),
            ),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => items[i],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: Color(0x14FFFFFF), shape: BoxShape.circle),
            child: const Center(child: KIcon(KIcons.bell, size: 52, color: _subtle, stroke: 1.7)),
          ),
          const SizedBox(height: 18),
          Text(
            'Ainda não houve chamadas desde que este ecrã as regista.',
            textAlign: TextAlign.center,
            style: KText.modalTitle.copyWith(fontSize: 34, color: Colors.white, letterSpacing: 0, height: 1.2),
          ),
          const SizedBox(height: 18),
          Text(
            'Sempre que tocarem à campainha, guardamos aqui uma imagem da porta, a hora e o que aconteceu.',
            textAlign: TextAlign.center,
            style: KText.s(20, color: _faint).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.call, required this.isNew, required this.picture, required this.onTap});

  final DoorbellCall call;
  final bool isNew;
  final Future<Uint8List?> picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = _Outcome.of(call);
    final ringing = call.ringing;
    final talk = call.talkTime;
    return KPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
        decoration: BoxDecoration(
          color: ringing ? const Color.fromRGBO(194, 65, 12, 0.18) : _rowBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            width: 2,
            color: ringing
                ? KColors.orange
                : isNew
                ? const Color.fromRGBO(229, 72, 77, 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 176,
              height: 104,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _Still(picture: picture, cacheWidth: 352, small: true),
                    ),
                  ),
                  if (ringing)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: KBlink(
                          period: const Duration(milliseconds: 1200),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_when(call.at), style: KText.s(24, weight: FontWeight.w600, color: Colors.white)),
                      if (isNew) ...[const SizedBox(width: 12), const _NewTag()],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      KIcon(o.icon, size: 24, color: o.fg, stroke: 2),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: o.label,
                            children: [
                              if (talk != null)
                                TextSpan(
                                  text: ' · ${_talk(talk)}',
                                  style: KText.s(20, weight: FontWeight.w500, color: _subtle),
                                ),
                            ],
                          ),
                          style: KText.s(20, weight: FontWeight.w600, color: o.fg),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (call.doorOpened) ...[const SizedBox(width: 12), const _DoorChip()],
            const SizedBox(width: 12),
            if (ringing)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(color: KColors.orange, borderRadius: BorderRadius.circular(28)),
                child: Row(
                  children: [
                    const KIcon(KIcons.video, size: 22, color: Colors.white, stroke: 2),
                    const SizedBox(width: 10),
                    Text('Ver câmara', style: KText.s(20, weight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              )
            else
              const KIcon(KIcons.chevronRight, size: 26, color: Color(0xFF6F757C), stroke: 2),
          ],
        ),
      ),
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _newRed, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text('NOVA', style: KText.s(14, weight: FontWeight.w700, color: Colors.white).copyWith(letterSpacing: 1)),
    );
  }
}

class _DoorChip extends StatelessWidget {
  const _DoorChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      decoration: BoxDecoration(color: _doorTint, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const KIcon(KIcons.lockOpen, size: 20, color: _doorFg, stroke: 2),
          const SizedBox(width: 8),
          Text('Porta aberta', style: KText.s(17, weight: FontWeight.w700, color: _doorFg)),
        ],
      ),
    );
  }
}

/// One call's picture in the camera's place, with ‹ › to the newer and
/// older calls, and what happened underneath.
class IntercomHistoryDetail extends StatelessWidget {
  const IntercomHistoryDetail({super.key, required this.calls, required this.index, required this.picture, required this.onIndex});

  final List<DoorbellCall> calls;
  final int index;
  final Future<Uint8List?> Function(DoorbellCall) picture;
  final ValueChanged<int> onIndex;

  @override
  Widget build(BuildContext context) {
    final c = calls[index];
    final o = _Outcome.of(c);
    final talk = c.talkTime;
    final newer = index > 0, older = index < calls.length - 1;
    Widget arrow(String icon, bool enabled, int to) => Opacity(
      opacity: enabled ? 1 : 0.3,
      child: KPress(
        onTap: enabled ? () => onIndex(to) : null,
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: Color.fromRGBO(23, 25, 28, 0.7), shape: BoxShape.circle),
          child: Center(child: KIcon(icon, size: 32, color: Colors.white, stroke: 2.2)),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 544,
          child: Stack(
            children: [
              Positioned.fill(child: _Still(picture: picture(c))),
              Positioned(
                top: 16,
                right: 20,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color.fromRGBO(23, 25, 28, 0.7), borderRadius: BorderRadius.circular(22)),
                  alignment: Alignment.center,
                  child: Text('${index + 1} de ${calls.length}', style: KText.s(17, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              Positioned(left: 20, top: 236, child: arrow(KIcons.chevronLeft, newer, index - 1)),
              Positioned(right: 20, top: 236, child: arrow(KIcons.chevronRight, older, index + 1)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: _rowBg,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_when(c.at), style: KText.modalTitle.copyWith(color: Colors.white)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _Fact(
                        icon: o.icon,
                        fg: o.fg,
                        tint: o.tint,
                        label: talk != null ? '${o.label} · ${_talk(talk)}' : o.label,
                        sub: talk != null ? '${o.sub} Duração: ${_talk(talk)}.' : o.sub,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: c.doorOpened
                          ? const _Fact(icon: KIcons.lockOpen, fg: _doorFg, tint: _doorTint, label: 'Porta aberta', sub: 'Durante ou logo a seguir à chamada.')
                          : const _Fact(icon: KIcons.lock, fg: _faint, tint: Color(0x14FFFFFF), label: 'Porta não foi aberta', sub: 'Nenhum dispositivo abriu a porta.'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.fg, required this.tint, required this.label, required this.sub});

  final String icon;
  final Color fg;
  final Color tint;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Center(child: KIcon(icon, size: 28, color: fg, stroke: 2)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KText.s(24, weight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(sub, style: KText.s(18, color: _subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A call's still, or the "no picture" placeholder once it's clear there is
/// none (small in a row, explained in the detail).
class _Still extends StatelessWidget {
  const _Still({required this.picture, this.cacheWidth, this.small = false});

  final Future<Uint8List?> picture;
  final int? cacheWidth;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: picture,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true, width: double.infinity, height: double.infinity);
        }
        final done = snap.connectionState == ConnectionState.done;
        return ColoredBox(
          color: const Color(0xFF24272C),
          child: !done
              ? null
              : small
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const KIcon(KIcons.cameraOff, size: 30, color: _faint, stroke: 1.8),
                    const SizedBox(height: 6),
                    Text('Sem imagem', style: KText.s(15, weight: FontWeight.w600, color: _faint)),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const KIcon(KIcons.cameraOff, size: 72, color: _faint, stroke: 1.5),
                    const SizedBox(height: 16),
                    Text('Não foi possível captar a imagem', style: KText.s(24, weight: FontWeight.w600, color: const Color(0xFFD6DADF))),
                    const SizedBox(height: 16),
                    Text('A câmara não respondeu no momento em que tocaram.', style: KText.s(18, color: _faint)),
                  ],
                ),
        );
      },
    );
  }
}
