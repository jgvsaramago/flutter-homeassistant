import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ha_providers.dart';
import '../data/house_config.dart';
import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import '../widgets/house_widgets.dart';
import '../widgets/kiosk_widgets.dart';
import 'intercom_modal.dart';

Future<void> showCameraModal(BuildContext context, String entityId) => showKModal(context, (_) => CameraModal(initial: entityId));

/// One camera, big and live (the design's "Modal de uma câmara"), with the
/// others in a strip below to switch to. The intercom's tile opens the
/// intercom instead.
class CameraModal extends ConsumerStatefulWidget {
  const CameraModal({super.key, required this.initial});

  final String initial;

  @override
  ConsumerState<CameraModal> createState() => _CameraModalState();
}

class _CameraModalState extends ConsumerState<CameraModal> {
  late String _shown = widget.initial;

  static const _muted = Color(0xFFB9BEC4);
  static const _glass = Color(0x1AFFFFFF);

  void _openIntercom() {
    final nav = Navigator.of(context);
    nav.maybePop();
    showIntercom(nav.context);
  }

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(houseConfigProvider.select((c) => c.cameras)).take(3).toList();
    final areas = ref.watch(areaByEntityIdProvider).valueOrNull ?? const <String, String>{};
    final cam = cameras.where((c) => c.entityId == _shown).firstOrNull ?? cameras.firstOrNull;
    if (cam == null) return const KModal(child: SizedBox(height: 120));
    String name(NamedEntity c) => c.name.isEmpty ? c.entityId : c.name;
    return KModal(
      width: 1040,
      background: KColors.dark,
      scrim: const Color(0xB80A0C0E),
      shadow: const BoxShadow(color: Color(0x73000000), blurRadius: 100, offset: Offset(0, 40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: _glass, shape: BoxShape.circle),
                child: const Center(child: KIcon(KIcons.video, size: 32, color: Colors.white)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name(cam), style: KText.modalTitle.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Câmara · ${areas[cam.entityId] ?? name(cam)}', style: KText.s(21, color: _muted)),
                  ],
                ),
              ),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: KColors.red, borderRadius: BorderRadius.circular(26)),
                child: Row(
                  children: [
                    KBlink(
                      period: const Duration(milliseconds: 1200),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ao vivo',
                      style: KText.s(20, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              KCircleButton(
                icon: KIcons.close,
                size: 64,
                iconSize: 26,
                stroke: 2.2,
                bg: _glass,
                fg: Colors.white,
                border: null,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: HaCameraTile(key: ValueKey(cam.entityId), entityId: cam.entityId, label: null, height: 544, radius: 32, every: const Duration(seconds: 1)),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: KPress(
                  onTap: _openIntercom,
                  child: Container(
                    height: 128,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: KColors.camera, borderRadius: BorderRadius.circular(20)),
                    child: const Stack(
                      children: [CameraCaption(label: 'Porta do Prédio', icon: KIcons.phone, size: 16)],
                    ),
                  ),
                ),
              ),
              for (final c in cameras) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: KPress(
                    onTap: c.entityId == cam.entityId ? null : () => setState(() => _shown = c.entityId),
                    child: HaCameraTile(
                      entityId: c.entityId,
                      label: name(c),
                      height: 128,
                      radius: 20,
                      labelSize: 16,
                      ring: c.entityId == cam.entityId ? Colors.white : null,
                    ),
                  ),
                ),
              ],
              for (var i = cameras.length; i < 3; i++) ...[const SizedBox(width: 12), const Spacer()],
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: KPress(
              onTap: () => Navigator.of(context).maybePop(),
              child: Column(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(color: Color(0x1FFFFFFF), shape: BoxShape.circle),
                    child: const Center(child: KIcon(KIcons.close, size: 40, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fechar',
                    style: KText.s(20, weight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
