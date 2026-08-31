import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';
import 'floating_save_button.dart';
import 'settings_save_controller.dart';

/// Shared shell for a settings drill-down page: a themed back arrow + title
/// header (this app has no `AppBar` anywhere else, so a bare `Scaffold`
/// would otherwise land with no way back except the OS, which this kiosk
/// doesn't expose), followed by the page's own slivers.
class SettingsSubPageScaffold extends StatelessWidget {
  const SettingsSubPageScaffold({super.key, required this.title, required this.slivers, this.saveController});

  final String title;
  final List<Widget> slivers;

  /// When set, floats a "Guardar" button over this page's bottom-right
  /// corner (see [FloatingSaveButton]) instead of the page's own card
  /// laying one out inline. The scroll content below reserves
  /// [FloatingSaveButton.height] plus this page's own margin at its bottom
  /// edge, so scrolling all the way down never leaves the button sitting on
  /// top of the last field. The button itself is positioned inside this
  /// `Scaffold`'s body, whose `resizeToAvoidBottomInset` (the default)
  /// already shrinks the body to sit above the on-screen keyboard whenever
  /// `OnScreenKeyboardHost` reports it showing — so the button rises with
  /// the keyboard for free, no extra keyboard-height plumbing needed here.
  final SettingsSaveController? saveController;

  static const _buttonMargin = 20.0;

  @override
  Widget build(BuildContext context) {
    final saveController = this.saveController;
    return Scaffold(
      backgroundColor: NocturneColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 30, 18, 28),
                    child: Row(
                      children: [
                        // Sized well past Material's own 48dp minimum: this is a
                        // wall-mounted kiosk with no OS-level back gesture, so
                        // this button is the *only* way out of a sub-page —
                        // worth erring large rather than tight, especially this
                        // close to the screen's edge where a finger has less
                        // room to land precisely.
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, color: NocturneColors.text, size: 34),
                          iconSize: 34,
                          padding: const EdgeInsets.all(20),
                          constraints: const BoxConstraints(minWidth: 80, minHeight: 80),
                          tooltip: 'Voltar',
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title, style: NocturneText.pageTitle, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
                ...slivers,
                SliverToBoxAdapter(
                  child: SizedBox(height: saveController == null ? 32 : FloatingSaveButton.height + _buttonMargin * 2),
                ),
              ],
            ),
            if (saveController != null)
              Positioned(
                right: _buttonMargin,
                bottom: _buttonMargin,
                child: FloatingSaveButton(controller: saveController),
              ),
          ],
        ),
      ),
    );
  }
}
