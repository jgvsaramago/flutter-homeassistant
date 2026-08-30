import 'package:flutter/material.dart';

/// A hot-water-tank icon (matches the energy-flow card's AQS node glyph in
/// the design reference) — not in Flutter's bundled Material icon set, so
/// it's drawn directly from the reference SVG's path data (24x24 viewBox:
/// a rounded tank body, two pipe stubs, two water waves) rather than pulled
/// in via an icon-font/SVG package for a single glyph. Stroked only, no
/// fill, matching `GridTowerIcon`'s sibling approach for the grid glyph.
class BoilerIcon extends StatelessWidget {
  const BoilerIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _BoilerPainter(color));
  }
}

class _BoilerPainter extends CustomPainter {
  const _BoilerPainter(this.color);

  final Color color;

  // Reference viewBox is 0 0 24 24, stroke-width 1.7, round caps/joins.
  static const _tankRect = Rect.fromLTWH(6.5, 5.5, 11, 16);
  static const _tankRadius = Radius.circular(3.5);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(_tankRect.left * scale, _tankRect.top * scale, _tankRect.width * scale, _tankRect.height * scale), Radius.circular(_tankRadius.x * scale)), paint);

    // Two pipe stubs off the tank's shoulder: M9.5,5.5 V3.5 H6.8 / M14.5,5.5 V3.5 H17.2
    canvas.drawPath(Path()..moveTo(p(9.5, 5.5).dx, p(9.5, 5.5).dy)..lineTo(p(9.5, 3.5).dx, p(9.5, 3.5).dy)..lineTo(p(6.8, 3.5).dx, p(6.8, 3.5).dy), paint);
    canvas.drawPath(Path()..moveTo(p(14.5, 5.5).dx, p(14.5, 5.5).dy)..lineTo(p(14.5, 3.5).dx, p(14.5, 3.5).dy)..lineTo(p(17.2, 3.5).dx, p(17.2, 3.5).dy), paint);

    // Two water waves: M9,14.5 q1.5,-1.6 3,0 t3,0 / M9,17.8 q1.5,-1.6 3,0 t3,0
    // (SVG relative quadratic + smooth-quadratic, expanded to absolute
    // control/end points ahead of time).
    canvas.drawPath(
      Path()
        ..moveTo(p(9, 14.5).dx, p(9, 14.5).dy)
        ..quadraticBezierTo(p(10.5, 12.9).dx, p(10.5, 12.9).dy, p(12, 14.5).dx, p(12, 14.5).dy)
        ..quadraticBezierTo(p(13.5, 16.1).dx, p(13.5, 16.1).dy, p(15, 14.5).dx, p(15, 14.5).dy),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(9, 17.8).dx, p(9, 17.8).dy)
        ..quadraticBezierTo(p(10.5, 16.2).dx, p(10.5, 16.2).dy, p(12, 17.8).dx, p(12, 17.8).dy)
        ..quadraticBezierTo(p(13.5, 19.4).dx, p(13.5, 19.4).dy, p(15, 17.8).dx, p(15, 17.8).dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BoilerPainter oldDelegate) => oldDelegate.color != color;
}
