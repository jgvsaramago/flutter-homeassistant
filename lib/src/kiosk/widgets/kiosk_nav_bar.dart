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
  settings('Definições', KIcons.settings);

  const KioskPage(this.label, this.icon);

  final String label;
  final String icon;
}

/// The bottom bar: six labelled destinations, Definições as an icon only,
/// then the assistant button.
class KioskNavBar extends StatelessWidget {
  const KioskNavBar({super.key, required this.selected, required this.onSelect, required this.onAssistant});

  final KioskPage selected;
  final ValueChanged<KioskPage> onSelect;
  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KColors.navBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 56),
      // Scale-down only as a guard: at the design's sizes the row fits.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            for (final p in KioskPage.values) ...[
              if (p != KioskPage.home) const SizedBox(width: 12),
              _NavItem(page: p, selected: p == selected, onTap: () => onSelect(p)),
            ],
            const SizedBox(width: 18),
            Container(width: 1.5, height: 56, color: KColors.navBorder),
            const SizedBox(width: 18),
            KCircleButton(
              icon: KIcons.wave,
              size: 88,
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
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.page, required this.selected, required this.onTap});

  final KioskPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : KColors.ink2;
    final iconOnly = page == KioskPage.settings;
    return KPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: kEase,
        height: 88,
        width: iconOnly ? 88 : null,
        padding: iconOnly ? null : EdgeInsets.symmetric(horizontal: selected ? 32 : 26),
        decoration: BoxDecoration(color: selected ? KColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(44)),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(page.icon, size: 30, color: fg, stroke: 1.9),
            if (!iconOnly) ...[
              const SizedBox(width: 12),
              Text(
                page.label,
                style: KText.s(22, weight: FontWeight.w600, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
