import 'package:flutter/material.dart';

/// A transmission-tower icon (matches the design reference's grid-node
/// glyph) — not in Flutter's bundled Material icon set, so it's drawn
/// directly from the reference SVG's path data (24x24 viewBox, straight
/// segments only) rather than pulled in via an icon-font/SVG package for
/// a single glyph.
class GridTowerIcon extends StatelessWidget {
  const GridTowerIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GridTowerPainter(color));
  }
}

class _GridTowerPainter extends CustomPainter {
  const _GridTowerPainter(this.color);

  final Color color;

  // Subpaths lifted from the reference's transmission-tower glyph
  // (viewBox 0 0 24 24): top insulator plate, mid crossbar, legs, and two
  // small diagonal-brace triangles.
  static const _subpaths = <List<Offset>>[
    [Offset(8.28, 5.45), Offset(6.5, 4.55), Offset(7.76, 2), Offset(16.23, 2), Offset(17.5, 4.55), Offset(15.72, 5.44), Offset(15, 4), Offset(9, 4)],
    [
      Offset(18.62, 8),
      Offset(14.09, 8),
      Offset(13.3, 5),
      Offset(10.7, 5),
      Offset(9.91, 8),
      Offset(5.38, 8),
      Offset(4.1, 10.55),
      Offset(5.89, 11.44),
      Offset(6.62, 10),
      Offset(17.38, 10),
      Offset(18.1, 11.45),
      Offset(19.89, 10.56),
    ],
    [
      Offset(17.77, 22),
      Offset(15.7, 22),
      Offset(15.46, 21.1),
      Offset(12, 15.9),
      Offset(8.53, 21.1),
      Offset(8.3, 22),
      Offset(6.23, 22),
      Offset(9.12, 11),
      Offset(11.19, 11),
      Offset(10.83, 12.35),
      Offset(12, 14.1),
      Offset(13.16, 12.35),
      Offset(12.81, 11),
      Offset(14.88, 11),
    ],
    [Offset(11.4, 15), Offset(10.5, 13.65), Offset(9.32, 18.13)],
    [Offset(14.68, 18.12), Offset(13.5, 13.64), Offset(12.6, 15)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path();
    for (final points in _subpaths) {
      path.moveTo(points.first.dx * scale, points.first.dy * scale);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * scale, point.dy * scale);
      }
      path.close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GridTowerPainter oldDelegate) => oldDelegate.color != color;
}
