import 'package:flutter/material.dart';

/// Per-field extras for the on-screen keyboard: a suggestion row computed
/// from what's typed so far, and what the accent "done" key says and does.
/// Fields that pass none (every settings screen) get the plain keyboard:
/// no suggestions, a "Concluído" key that just closes it.
class KeyboardOptions {
  const KeyboardOptions({this.suggestions, this.doneLabel = 'Concluído', this.onDone, this.onSuggest, this.capitalize = true});

  /// Given the field's current text, the chips to offer above the keys.
  final List<String> Function(String text)? suggestions;
  final String doneLabel;

  /// Runs instead of closing the keyboard — e.g. moving focus to the next
  /// field of a form. Null closes the keyboard.
  final VoidCallback? onDone;

  /// What tapping a suggestion does. Null replaces the field's text with it.
  final ValueChanged<String>? onSuggest;

  /// Auto-shift at the start of the field and after sentence punctuation.
  final bool capitalize;
}

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

  /// Options for whichever field is [active]. Set together with it.
  KeyboardOptions options = const KeyboardOptions();

  void attach(TextEditingController controller, {KeyboardOptions options = const KeyboardOptions()}) {
    this.options = options;
    active.value = controller;
  }

  /// No-ops if [controller] isn't the currently-attached one — guards
  /// against a stale blur from a field that's already lost the "race" to a
  /// newly-focused one.
  void detach(TextEditingController controller) {
    if (active.value == controller) active.value = null;
  }

  /// Closes the keyboard and drops focus from whichever field had it, so
  /// the field's own focus listener and this stay in step.
  void close() {
    active.value = null;
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
