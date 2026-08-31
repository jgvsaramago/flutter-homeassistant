import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';
import 'sheet.dart';

/// Always the first child of a [Sheet]. Doubles as a dismiss target, same
/// as tapping the scrim.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.paddingBottom = 30});

  /// 22 on sheets with their own header row above the content; 30 (the
  /// default) on sheets that open straight into content.
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: paddingBottom),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => SheetController.of(context).close(),
          child: Container(
            width: 64,
            height: 5,
            decoration: BoxDecoration(color: NocturneColors.neutral700, borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
    );
  }
}

/// A kicker-style section title with an optional trailing meta string —
/// marks the start of one distinct region of a sheet's content (e.g.
/// "Interior" / "Sala").
class SheetSectionHeader extends StatelessWidget {
  const SheetSectionHeader({super.key, required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, decoration: TextDecoration.none, letterSpacing: 2.04, color: NocturneColors.accent),
          ),
          if (meta != null)
            Text(meta!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral500)),
        ],
      ),
    );
  }
}

/// The big reading at the top of a sheet section — a value+unit pair, an
/// optional trailing aside, and an optional right-aligned min/max line
/// beneath it.
class SheetHero extends StatelessWidget {
  const SheetHero({super.key, required this.value, required this.unit, this.aside, this.minmax});

  final String value;
  final String unit;
  final String? aside;
  final String? minmax;

  static final _valueStyle = TextStyle(fontSize: 64, fontWeight: FontWeight.w600, decoration: TextDecoration.none, height: 1, letterSpacing: -1.28, color: NocturneColors.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // U+00A0 (non-breaking space): the unit must never wrap onto
              // its own line, away from the number it qualifies.
              Text('$value $unit', style: _valueStyle),
              if (aside != null) ...[
                const SizedBox(width: 20),
                Flexible(
                  child: Text(aside!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral400)),
                ),
              ],
            ],
          ),
        ),
        if (minmax != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(minmax!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal, decoration: TextDecoration.none, color: NocturneColors.neutral500)),
            ),
          ),
      ],
    );
  }
}
