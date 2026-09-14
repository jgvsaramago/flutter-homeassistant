import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ha_entity.dart';
import '../../providers/ha_providers.dart';
import '../../providers/rooms_store.dart';
import '../../theme/nocturne_theme.dart';

/// One shutter card on the Climatização page — the reference design's
/// "window, vertical controls" layout (option 2a): a slatted window
/// thumbnail, position/state text, and a control column that swaps between
/// two arrows (idle) and a single stop button (moving) rather than showing
/// three buttons at once.
///
/// Backed by a real `cover.*` entity (see [RoomConfig.coverEntityId]).
/// Position comes from the entity's `current_position` attribute when the
/// integration reports one; a cover with only open/closed states falls
/// back to 100/0, same convention `RoomView`'s own blinds colour already
/// uses.
class ShutterCard extends ConsumerWidget {
  const ShutterCard({super.key, required this.room, required this.entity});

  final RoomConfig room;
  final HaEntity? entity;

  bool get _unavailable => entity == null || entity!.isUnavailable;

  int get _pos {
    if (_unavailable) return 0;
    final raw = entity!.attributes['current_position'];
    if (raw is num) return raw.round().clamp(0, 100);
    return entity!.state == 'closed' ? 0 : 100;
  }

  /// 1 = opening, -1 = closing, 0 = idle.
  int get _moving {
    if (_unavailable) return 0;
    if (entity!.state == 'opening') return 1;
    if (entity!.state == 'closing') return -1;
    return 0;
  }

  Future<void> _call(WidgetRef ref, String service) async {
    if (entity == null) return;
    final client = ref.read(haWebSocketClientProvider);
    await client.callService('cover', service, target: {'entity_id': entity!.entityId});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = _pos;
    final moving = _moving;
    final posLabel = pos >= 100 ? 'Aberto' : (pos <= 0 ? 'Fechado' : '$pos%');
    final posColor = pos > 0 ? NocturneColors.text : NocturneColors.neutral300;
    final stateLabel = moving == 1
        ? 'a abrir…'
        : moving == -1
        ? 'a fechar…'
        : (pos >= 100 ? 'no topo' : (pos <= 0 ? 'em baixo' : 'aberto'));
    final stateColor = moving != 0 ? const Color(0xFF84B4E6) : NocturneColors.neutral500;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _WindowThumbnail(closedFraction: (100 - pos) / 100),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, height: 1.15, fontWeight: FontWeight.w500, color: NocturneColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  _unavailable ? 'Indisponível' : posLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: posColor),
                ),
                const SizedBox(height: 6),
                Text(_unavailable ? '' : stateLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.15, color: stateColor)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          moving != 0
              ? _StopButton(onTap: _unavailable ? null : () => _call(ref, 'stop_cover'))
              : _ArrowColumn(
                  upEnabled: !_unavailable && pos < 100,
                  downEnabled: !_unavailable && pos > 0,
                  onUp: () => _call(ref, 'open_cover'),
                  onDown: () => _call(ref, 'close_cover'),
                ),
        ],
      ),
    );
  }
}

class _WindowThumbnail extends StatelessWidget {
  const _WindowThumbnail({required this.closedFraction});

  /// 0 = fully open (no slats visible), 1 = fully closed (slats cover the
  /// whole window).
  final double closedFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 84,
        height: 112,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C3450), Color(0xFF16283D)])),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 260),
              curve: Curves.linear,
              widthFactor: 1,
              heightFactor: closedFraction.clamp(0, 1),
              child: const CustomPaint(painter: _SlatsPainter(), child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Repeating horizontal slats — the literal shutter: closed covers the
/// whole window, open covers none of it (see [_WindowThumbnail]).
class _SlatsPainter extends CustomPainter {
  const _SlatsPainter();

  static const _barHeight = 6.0;
  static const _gapHeight = 2.0;
  static const _bar = Color(0xFF5C5E66);
  static const _gap = Color(0xFF4A4C53);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _gap);
    final paint = Paint()..color = _bar;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, _barHeight), paint);
      y += _barHeight + _gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowColumn extends StatelessWidget {
  const _ArrowColumn({required this.upEnabled, required this.downEnabled, required this.onUp, required this.onDown});

  final bool upEnabled;
  final bool downEnabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(icon: Icons.keyboard_arrow_up, enabled: upEnabled, onTap: onUp),
        const SizedBox(height: 8),
        _ArrowButton(icon: Icons.keyboard_arrow_down, enabled: downEnabled, onTap: onDown),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NocturneColors.neutral900,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, size: 26, color: enabled ? NocturneColors.neutral300 : NocturneColors.neutral500),
        ),
      ),
    );
  }
}

/// Replaces the two arrows entirely while the cover is moving — deliberate,
/// not "3 buttons always visible": see `PROMPT-04-climate-page.md` Part D.
class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.lerp(NocturneColors.surface, const Color(0xFFA33A34), 0.32),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          width: 52,
          height: 112,
          child: Center(child: Icon(Icons.stop_rounded, size: 22, color: Color(0xFFF0A49E))),
        ),
      ),
    );
  }
}
