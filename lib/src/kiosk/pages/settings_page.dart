import 'package:flutter/material.dart';

import '../../pages/settings/settings_screen.dart';
import '../kiosk_canvas.dart';

/// Definições: the existing device settings screens (brightness, reboot,
/// connections …), drawn at their original 720-wide scale inside the page
/// area, with their own navigator so a sub-page opens in place rather
/// than over the whole kiosk.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: LegacyScale(
        child: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    );
  }
}
