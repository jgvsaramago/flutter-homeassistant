import 'package:flutter/material.dart';

import 'on_screen_keyboard_controller.dart';

/// Drop-in replacement for `TextField` that registers itself with
/// [OnScreenKeyboardController] on focus/blur, so `OnScreenKeyboardHost`
/// shows the on-screen keyboard for it. Anywhere in the app that needs
/// plain text entry (not the entity autocomplete field, which wires this
/// same controller up itself) should use this instead of a bare `TextField`.
class KeyboardTextField extends StatefulWidget {
  const KeyboardTextField({super.key, required this.controller, this.decoration, this.onChanged, this.focusNode});

  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<KeyboardTextField> createState() => _KeyboardTextFieldState();
}

class _KeyboardTextFieldState extends State<KeyboardTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final bool _ownsFocusNode = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    // A direct listener on the controller, not `TextField`'s own
    // `onChanged:` parameter — matching `EntityIdField`/`_ThresholdField`'s
    // proven-reliable pattern elsewhere in this app. The on-screen
    // keyboard's `_insert`/`_backspace` mutate the controller's `.value`
    // directly (see `on_screen_keyboard.dart`), and on the real kiosk that
    // reliably repaints the field's visible text but was found to *not*
    // reliably reach `TextField.onChanged` — a name typed via the on-screen
    // keyboard would show on screen yet never actually update the widget
    // that reads it, so it silently dropped out of Settings saves. A plain
    // controller listener responds to any value change unconditionally,
    // the same way `ValueNotifier.notifyListeners` does, independent of
    // `EditableText`'s own internal onChanged-triggering path.
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() => widget.onChanged?.call(widget.controller.text);

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      OnScreenKeyboardController.instance.attach(widget.controller);
    } else {
      OnScreenKeyboardController.instance.detach(widget.controller);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onControllerChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      // No onChanged here — the controller listener above already covers
      // it, and passing both would fire onChanged twice per keystroke.
      // onTapOutside is left at its default: on this app's target platform
      // (Linux, via flutter-pi) that unfocuses on any tap outside the
      // field, which is exactly the desired "tap away closes the keyboard"
      // behavior. The keyboard panel itself is wrapped in a
      // TextFieldTapRegion (see on_screen_keyboard.dart) so tapping a key
      // doesn't count as "outside" and blur the field mid-keystroke.
    );
  }
}
