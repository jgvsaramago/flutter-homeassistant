import 'package:flutter/material.dart';

/// Shared visual container for every entity card: icon, title, and a slot
/// for domain-specific content (a switch, buttons, a value label, ...).
class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor),
                  const Spacer(),
                  // Flexible so a value-text child (e.g. InfoCard's "21.5°C")
                  // ellipsizes instead of overflowing a narrow grid cell —
                  // without a bound, `overflow: TextOverflow.ellipsis` on the
                  // child has nothing to ellipsize against.
                  Flexible(child: child),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
