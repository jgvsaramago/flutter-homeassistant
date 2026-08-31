import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';
import 'room_view_model.dart';

/// One Divisões card: name, hero temperature, an optional status line, a
/// status dot, and an icon row (light, window, blinds, A/C, speaker) — only
/// for whichever of those the room actually has an entity for, lit or
/// dimmed per [RoomView]. A capability with no entity at all is omitted
/// rather than shown as a permanently-dim icon.
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.view});

  final RoomView view;

  @override
  Widget build(BuildContext context) {
    final subText = view.subText;
    final icons = [
      if (view.hasLight) Icon(Icons.lightbulb_outline, size: 24, color: view.lightIconColor),
      if (view.hasWindow) Icon(Icons.window, size: 24, color: view.windowIconColor),
      if (view.hasBlinds) Icon(Icons.blinds, size: 24, color: view.blindsIconColor),
      if (view.hasAc) Icon(Icons.ac_unit, size: 24, color: view.acIconColor),
      if (view.hasSpeaker) Icon(Icons.speaker, size: 24, color: view.speakerIconColor),
    ];
    return Container(
      decoration: BoxDecoration(color: NocturneColors.surface, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      view.config.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          view.tempText,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1, height: 1),
                        ),
                        const SizedBox(width: 3),
                        Text('°C', style: TextStyle(fontSize: 16, color: NocturneColors.neutral500)),
                      ],
                    ),
                    if (subText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subText,
                        style: TextStyle(fontSize: 15, color: NocturneColors.neutral500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: view.dotColor),
              ),
            ],
          ),
          if (icons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [for (final icon in icons) ...[icon, const SizedBox(width: 14)]]..removeLast(),
              ),
            ),
        ],
      ),
    );
  }
}
