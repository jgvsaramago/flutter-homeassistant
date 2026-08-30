import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';
import 'settings_save_controller.dart';

/// The floating "Guardar" action every settings sub-page anchors to its
/// bottom-right corner — see `SettingsSubPageScaffold` for how it's
/// positioned, how the page reserves room for it, and how it rises above
/// the on-screen keyboard. Morphs into a "Guardado" state in place (rather
/// than showing a separate check + label beside it, like the old inline
/// button did) since a floating corner button has no natural place to grow
/// into without shifting position.
class FloatingSaveButton extends StatelessWidget {
  const FloatingSaveButton({super.key, required this.controller});

  final SettingsSaveController controller;

  /// Both states render at this same height — `SettingsSubPageScaffold`
  /// uses it to reserve exactly enough room at the scroll content's bottom
  /// edge that the button never ends up covering the last field.
  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.saving,
      builder: (context, saving, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: controller.saved,
          builder: (context, saved, _) {
            return SizedBox(
              height: height,
              child: FilledButton.icon(
                onPressed: saving ? null : () => controller.requestSave(),
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Icon(saved ? Icons.check_circle : Icons.save_outlined, size: 22),
                label: Text(saving ? 'A guardar...' : (saved ? 'Guardado' : 'Guardar')),
                style: FilledButton.styleFrom(
                  backgroundColor: saved && !saving ? NocturneColors.batteryMark : null,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  elevation: 6,
                  shadowColor: const Color(0x8C000000),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
