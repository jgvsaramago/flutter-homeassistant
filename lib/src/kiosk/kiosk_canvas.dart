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

/// Renders [child] — UI built for a narrower logical width (the original
/// 720-wide dashboard's settings screens) — at [logicalWidth] and scales it
/// up to fill the space it's given, converting keyboard insets to match.
class LegacyScale extends StatelessWidget {
  const LegacyScale({super.key, required this.child, this.logicalWidth = 720});

  final Widget child;
  final double logicalWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = c.maxWidth / logicalWidth;
        final mq = MediaQuery.of(context);
        final size = Size(logicalWidth, c.maxHeight / scale);
        return FittedBox(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: mq.copyWith(size: size, viewInsets: mq.viewInsets / scale, devicePixelRatio: mq.devicePixelRatio * scale),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
