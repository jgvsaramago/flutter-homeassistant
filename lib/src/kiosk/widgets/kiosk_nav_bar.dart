import 'package:flutter/material.dart';

import '../theme/kiosk_icons.dart';
import '../theme/kiosk_tokens.dart';
import 'kiosk_widgets.dart';

enum KioskPage {
  home('Início', KIcons.navHome),
  calendar('Calendário', KIcons.calendar),
  tasks('Tarefas', KIcons.tasks),
  meals('Refeições', KIcons.meals),
  lists('Listas', KIcons.list),
  house('Casa', KIcons.house),
  music('Música', KIcons.music),

  /// Not in the bar: opened by tapping the header's clock.
  settings('Definições', KIcons.settings);

  const KioskPage(this.label, this.icon);

  final String label;
  final String icon;
}

/// The bottom bar: seven labelled destinations, then the assistant button.
/// Definições isn't here — the header's clock opens it.
///
/// As in the design (`flex: 1 1 auto`), each destination is its own
/// content width plus an equal share of the room left over, so the pills
/// fill the bar edge to edge.
class KioskNavBar extends StatelessWidget {
  const KioskNavBar({super.key, required this.selected, required this.onSelect, required this.onAssistant});

  final KioskPage selected;
  final ValueChanged<KioskPage> onSelect;
  final VoidCallback onAssistant;

  static const _gap = 8.0;
  static const _icon = 30.0;
  static const _iconGap = 12.0;
  static const _padX = 12.0;
  static const _assistant = 88.0;
  static const _divider = 1.5 + 2 * 6;

  static final _pages = [
    for (final p in KioskPage.values)
      if (p != KioskPage.settings) p,
  ];

  static double _contentWidth(KioskPage p) {
    final tp = TextPainter(
      text: TextSpan(text: p.label, style: KText.s(22, weight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return _padX * 2 + _icon + _iconGap + tp.width;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KColors.navBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: LayoutBuilder(
        builder: (context, box) {
          final widths = [for (final p in _pages) _contentWidth(p)];
          final fixed = widths.fold<double>(0, (a, w) => a + w) + _gap * (_pages.length + 1) + _divider + _assistant;
          final extra = ((box.maxWidth - fixed) / _pages.length).clamp(0.0, double.infinity);
          return Center(
            // Scale-down only as a guard: at the design's sizes the row fits.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    _NavItem(page: _pages[i], width: widths[i] + extra, selected: _pages[i] == selected, onTap: () => onSelect(_pages[i])),
                  ],
                  const SizedBox(width: _gap),
                  Container(width: 1.5, height: 56, margin: const EdgeInsets.symmetric(horizontal: 6), color: KColors.navBorder),
                  const SizedBox(width: _gap),
                  KCircleButton(
                    icon: KIcons.wave,
                    size: _assistant,
                    iconSize: 36,
                    stroke: 2.2,
                    bg: KColors.accent,
                    fg: Colors.white,
                    border: null,
                    shadow: const [BoxShadow(color: Color(0x591F4D45), blurRadius: 16, offset: Offset(0, 6))],
                    onTap: onAssistant,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.page, required this.width, required this.selected, required this.onTap});

  final KioskPage page;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : KColors.ink2;
    return KPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: kEase,
        width: width,
        height: 88,
        decoration: BoxDecoration(color: selected ? KColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(44)),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(page.icon, size: KioskNavBar._icon, color: fg, stroke: 1.9),
            const SizedBox(width: KioskNavBar._iconGap),
            Text(page.label, maxLines: 1, style: KText.s(22, weight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
