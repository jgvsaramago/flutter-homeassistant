import 'package:flutter/material.dart';

/// App-wide handle for which `TextEditingController` should currently be
/// receiving on-screen-keyboard input. flutter-pi (this app's real target)
/// has no native IME — focusing a text field there shows nothing at all,
/// unlike Android/iOS/desktop/web, which all pop a real keyboard on their
/// own. Any text-entry widget attaches itself here on focus and detaches on
/// blur; `OnScreenKeyboardHost` (mounted once at the app root) reacts to
/// that to show/hide the keyboard panel and know where typed keys go.
class OnScreenKeyboardController {
  OnScreenKeyboardController._();

  static final instance = OnScreenKeyboardController._();

  final ValueNotifier<TextEditingController?> active = ValueNotifier(null);

  void attach(TextEditingController controller) => active.value = controller;

  /// No-ops if [controller] isn't the currently-attached one — guards
  /// against a stale blur from a field that's already lost the "race" to a
  /// newly-focused one.
  void detach(TextEditingController controller) {
    if (active.value == controller) active.value = null;
  }

  void close() => active.value = null;
}
