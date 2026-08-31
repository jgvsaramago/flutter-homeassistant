import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _barHeight = 96.0;
const _barRadius = NocturneRadii.floatingNavbar;
const _pillHeight = 70.0;
const _pillRadius = NocturneRadii.navPill;
const _pillAnimDuration = NocturneDurations.colorChange;

/// Floating bottom nav bar in the Nocturne design's pill style: a fixed-size
/// 5-column grid whose outer box never changes shape as selection moves —
/// only the content of each column does. The selected column gets an
/// accent-tinted icon+label pill; the rest show a bare neutral icon.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.selectedIndex, required this.onSelect});

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// How much space the floating bar actually occupies from the bottom of
  /// the screen — its own fixed height plus the margin [MainShell] lifts it
  /// by. Never data-dependent (the bar's own height doesn't change with
  /// content or selection), so scrollable tab content behind it can reserve
  /// exactly this much clearance instead of a guessed round number. Add
  /// `MediaQuery.paddingOf(context).bottom` on top for devices with a
  /// bottom safe-area inset.
  static const floatingClearance = _barHeight + 14.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_barRadius),
        boxShadow: [NocturneElevation.navbarShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_barRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: _barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: NocturneColors.surface.withValues(alpha: 0.94),
              border: Border.all(color: NocturneElevation.navbarBorder),
              borderRadius: BorderRadius.circular(_barRadius),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavColumn(item: items[i], selected: i == selectedIndex, onTap: () => onSelect(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavColumn extends StatelessWidget {
  const _NavColumn({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: _pillAnimDuration,
            curve: Curves.easeOut,
            height: _pillHeight,
            padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 0),
            decoration: BoxDecoration(
              color: selected ? NocturneColors.accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(_pillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 28,
                  color: selected ? NocturneColors.accent : NocturneColors.neutral600,
                ),
                AnimatedSize(
                  duration: _pillAnimDuration,
                  curve: Curves.easeOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            item.label,
                            style: NocturneText.navLabel.copyWith(color: NocturneColors.accent),
                          ),
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
