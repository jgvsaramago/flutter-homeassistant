import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

/// A settings row that drills into a sub-page — leading icon, title,
/// optional subtitle, trailing chevron. Used to build the settings
/// hierarchy (Definições → Cartão de Energia, say) without every leaf
/// page's fields cluttering the top-level list.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({super.key, required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NocturneRadii.primaryCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: NocturneColors.accent, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: NocturneText.itemTitle),
                    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: NocturneText.body)],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: NocturneColors.neutral500, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
