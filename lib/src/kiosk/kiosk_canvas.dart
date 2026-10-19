import 'package:flutter/material.dart';

import 'theme/kiosk_tokens.dart';

/// The design's frame: a 22" QHD panel in portrait.
const kCanvasSize = Size(1440, 2560);

/// Lays the whole app out on a fixed 1440×2560 canvas and scales that to
/// whatever the display actually reports. flutter-pi derives its device
/// pixel ratio from the panel's physical size, so the same 2560×1440 panel
/// can come up as anything from ~1000 to 1440 logical pixels wide; drawing
/// in design pixels and scaling once here keeps every size in the design
/// exact regardless. Any other aspect ratio (a browser preview) is
/// letterboxed rather than reflowed.
class KioskCanvas extends StatelessWidget {
  const KioskCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KColors.page,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return child;
          final mq = MediaQuery.of(context);
          final scale = (constraints.maxWidth / kCanvasSize.width).clamp(0.0, constraints.maxHeight / kCanvasSize.height);
          return Center(
            child: SizedBox(
              width: kCanvasSize.width * scale,
              height: kCanvasSize.height * scale,
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: kCanvasSize,
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: kCanvasSize,
                      devicePixelRatio: mq.devicePixelRatio * scale,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                      textScaler: TextScaler.noScaling,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
