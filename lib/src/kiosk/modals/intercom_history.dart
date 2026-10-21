import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/doorbell_history.dart';
import '../data/pt_dates.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/kiosk_widgets.dart';

const _subtle = Color(0xFFB9BEC4);
const _missed = Color(0xFFF59F8B);
const _answered = Color(0xFF8CD69C);

/// "Hoje", "Ontem", or "Ter, 14 out" (+ the year when it isn't this one).
String _day(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  final s = '${PtDates.abbrTitle[d.weekday - 1]}, ${PtDates.short(d)}';
  return d.year == now.year ? s : '$s ${d.year}';
}

String _talk(Duration d) => '${d.inMinutes}:${PtDates.two(d.inSeconds % 60)}';

/// What happened to the call, and its colour on the dark intercom card.
(String, Color) _outcome(DoorbellCall c) {
  if (c.endedAt == null) return ('A tocar agora', KColors.amber);
  if (c.answeredIndoor) {
    final t = c.talkTime;
    return (['Atendida no intercomunicador', if (t != null) _talk(t)].join(' · '), _answered);
  }
  if (c.answeredHere) return ('Ouvida neste ecrã', _answered);
  return ('Não atendida', _missed);
}

/// The intercom card's history list: newest first, each ring with the
/// still taken when it started. Lives in the camera's slot so a ring can
/// switch straight back to the live view.
class IntercomHistoryList extends StatelessWidget {
  const IntercomHistoryList({super.key, required this.history, required this.pictures, required this.onPick});

  final DoorbellHistory history;

  /// Thumbnails already loaded, kept by the modal across rebuilds.
  final Future<Uint8List?> Function(DoorbellCall) pictures;
  final ValueChanged<DoorbellCall> onPick;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DoorbellCall>>(
      valueListenable: history.calls,
      builder: (context, calls, _) {
        if (calls.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const KIcon(KIcons.bell, size: 64, color: Color(0xFF9AA0A6), stroke: 1.5),
              const SizedBox(height: 14),
              Text('Ainda não houve chamadas desde que este ecrã as regista.', style: KText.s(22, color: const Color(0xFF9AA0A6))),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: calls.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _Row(call: calls[i], picture: pictures(calls[i]), onTap: () => onPick(calls[i])),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.call, required this.picture, required this.onTap});

  final DoorbellCall call;
  final Future<Uint8List?> picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (outcome, color) = _outcome(call);
    return KPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: 192, height: 108, child: _Still(picture: picture, cacheWidth: 384)),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_day(call.at)} · ${PtDates.hm(call.at)}',
                    style: KText.s(26, weight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    outcome,
                    style: KText.s(20, weight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            ),
            if (call.doorOpened) const _DoorOpenedChip(),
            const SizedBox(width: 8),
            const KIcon(KIcons.chevronRight, size: 28, color: _subtle, stroke: 2),
          ],
        ),
      ),
    );
  }
}

class _DoorOpenedChip extends StatelessWidget {
  const _DoorOpenedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0x332B8A3E), borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KIcon(KIcons.lockOpen, size: 22, color: _answered, stroke: 2),
          const SizedBox(width: 8),
          Text(
            'Porta aberta',
            style: KText.s(18, weight: FontWeight.w600, color: _answered),
          ),
        ],
      ),
    );
  }
}

/// One call's picture filling the camera slot, with what happened on top.
class IntercomHistoryPicture extends StatelessWidget {
  const IntercomHistoryPicture({super.key, required this.call, required this.picture});

  final DoorbellCall call;
  final Future<Uint8List?> picture;

  @override
  Widget build(BuildContext context) {
    final (outcome, color) = _outcome(call);
    return Stack(
      children: [
        Positioned.fill(child: _Still(picture: picture)),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(color: const Color(0xC717191C), borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Text(
                  '${_day(call.at)} · ${PtDates.hm(call.at)}',
                  style: KText.s(24, weight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    outcome,
                    style: KText.s(20, weight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (call.doorOpened) const _DoorOpenedChip(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Still extends StatelessWidget {
  const _Still({required this.picture, this.cacheWidth});

  final Future<Uint8List?> picture;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: picture,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true, width: double.infinity, height: double.infinity);
        }
        return ColoredBox(
          color: KColors.camera,
          child: Center(
            child: snap.connectionState == ConnectionState.done ? const KIcon(KIcons.video, size: 32, color: Color(0xFF9AA0A6), stroke: 1.5) : null,
          ),
        );
      },
    );
  }
}
