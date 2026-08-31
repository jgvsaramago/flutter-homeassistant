import 'package:flutter/material.dart';

import '../theme/nocturne_theme.dart';
import 'on_screen_keyboard_controller.dart';

/// Mounted once at the app root (see `app.dart`): shows the on-screen
/// keyboard docked to the bottom of the screen whenever
/// [OnScreenKeyboardController] has an attached field, on top of [child].
///
/// Also reports the keyboard's own height to [child] as
/// `MediaQuery.viewInsets.bottom` while it's showing — the same signal a
/// real system keyboard sends. This app's keyboard is just an ordinary
/// overlay widget, not an IME, so Flutter has no idea it's covering
/// anything unless told: without this, every `Scaffold` behind it (every
/// settings page) had no reason to shrink/scroll out of its way, and
/// `TextField`'s own built-in "scroll the focused field above the keyboard"
/// behavior — which keys off this exact value — never had anything to
/// react to either. Feeding it this way means both behaviors come from
/// Flutter's existing machinery instead of being reimplemented here.
class OnScreenKeyboardHost extends StatefulWidget {
  const OnScreenKeyboardHost({super.key, required this.child});

  final Widget child;

  @override
  State<OnScreenKeyboardHost> createState() => _OnScreenKeyboardHostState();
}

class _OnScreenKeyboardHostState extends State<OnScreenKeyboardHost> {
  final _keyboardKey = GlobalKey();
  double _keyboardHeight = 0;

  // The keyboard's row count never changes between its letter/symbol
  // layouts (see `_letterRows`/`_symbolRows`, both exactly 4 rows), so one
  // measurement per time it mounts is enough — no need to remeasure on
  // every shift/symbols toggle or keystroke.
  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _keyboardKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height;
      if (height != null && height != _keyboardHeight) setState(() => _keyboardHeight = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingController?>(
      valueListenable: OnScreenKeyboardController.instance.active,
      builder: (context, controller, _) {
        final showing = controller != null;
        if (showing) _measureAfterFrame();

        final mediaQuery = MediaQuery.of(context);
        final reportedInset = showing ? _keyboardHeight : 0.0;

        return Stack(
          children: [
            MediaQuery(
              data: mediaQuery.copyWith(
                viewInsets: mediaQuery.viewInsets.copyWith(
                  bottom: reportedInset > mediaQuery.viewInsets.bottom ? reportedInset : mediaQuery.viewInsets.bottom,
                ),
              ),
              child: widget.child,
            ),
            if (showing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: KeyedSubtree(
                    key: _keyboardKey,
                    child: _OnScreenKeyboard(key: ValueKey(controller), controller: controller),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OnScreenKeyboard extends StatefulWidget {
  const _OnScreenKeyboard({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<_OnScreenKeyboard> createState() => _OnScreenKeyboardState();
}

enum _Layout { letters, symbols, accents }

class _OnScreenKeyboardState extends State<_OnScreenKeyboard> {
  bool _shift = false;
  _Layout _layout = _Layout.letters;

  void _insert(String text) {
    final value = widget.controller.value;
    var selection = value.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: value.text.length);
    }
    final start = selection.start;
    final end = selection.end;
    final newText = value.text.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: start + text.length));
    if (_shift) setState(() => _shift = false);
    // Accents is a one-shot layout, same idea as shift: a Portuguese word
    // typically needs exactly one accented letter surrounded by plain ones
    // ("não", "está"), so forcing an explicit trip back to "ABC" after
    // every single accent would make ordinary typing tedious. Symbols
    // stays sticky — numbers/punctuation are more often typed in a run.
    if (_layout == _Layout.accents) setState(() => _layout = _Layout.letters);
  }

  void _backspace() {
    final value = widget.controller.value;
    var selection = value.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: value.text.length);
    }
    if (selection.start != selection.end) {
      _insert('');
      return;
    }
    final start = selection.start;
    if (start <= 0) return;
    final newText = value.text.replaceRange(start - 1, start, '');
    widget.controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: start - 1));
  }

  void _close() => OnScreenKeyboardController.instance.close();

  @override
  Widget build(BuildContext context) {
    // TextFieldTapRegion marks this panel as part of the focused field's own
    // tap region even though it's mounted at the app root, entirely outside
    // that field's widget subtree — the same mechanism a real IME's
    // predictive-text bar or a text-selection toolbar uses. Without it, a
    // key tap here would register as "tapped outside the field" and blur it
    // (dropping the keystroke) under the tap-outside-closes-keyboard
    // behavior each field now uses (see entity_id_field.dart/
    // keyboard_text_field.dart) — every *other* tap on the page still
    // outside this region, so it still closes the keyboard as expected. An
    // ExcludeFocus wrapper was tried first, but its includeSemantics:false
    // broke pointer hit-testing under the semantics-routed input path
    // Flutter web can switch to, for no benefit once TextFieldTapRegion was
    // already handling the actual problem.
    return TextFieldTapRegion(
      child: Container(
        // Extra side/bottom margin (vs. just 8/12 originally) so the
        // outermost keys sit well clear of the physical screen edges — this
        // panel's touch digitizer is noticeably less reliable right at its
        // borders. Top is left tight: it isn't near a physical edge, it just
        // borders whatever's above the keyboard on screen.
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
        decoration: BoxDecoration(
          color: NocturneColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(NocturneRadii.smallCard)),
          boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: switch (_layout) {
            _Layout.letters => _letterRows(),
            _Layout.symbols => _symbolRows(),
            _Layout.accents => _accentRows(),
          },
        ),
      ),
    );
  }

  String _cased(String k) => _shift ? k.toUpperCase() : k;

  /// The bottom row's non-space keys, split evenly on either side of
  /// "espaço" so the space key actually sits at the row's centre — 2 keys
  /// of equal flex on each side, never an odd count that can't balance.
  Widget _bottomRow({required Widget left1, required Widget left2, required Widget right1, required Widget right2}) {
    return _row([left1, left2, _labelKey('espaço', flex: 7, onTap: () => _insert(' ')), right1, right2]);
  }

  List<Widget> _letterRows() {
    const row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    const row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    const row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return [
      _row([for (final k in row1) _charKey(_cased(k))]),
      _row([const SizedBox(width: 26), ...[for (final k in row2) _charKey(_cased(k))], const SizedBox(width: 26)]),
      _row([
        // flex 3, up from 2 — shift used to be a visibly narrower target
        // than backspace on the same row despite being tapped just as
        // often (every capitalized name needs it); now the two match.
        _specialKey(icon: Icons.arrow_upward, active: _shift, onTap: () => setState(() => _shift = !_shift), flex: 3),
        ...[for (final k in row3) _charKey(_cased(k))],
        _specialKey(icon: Icons.backspace_outlined, onTap: _backspace, flex: 3),
      ]),
      _bottomRow(
        left1: _labelKey('123', flex: 2, onTap: () => setState(() => _layout = _Layout.symbols)),
        left2: _labelKey('áã', flex: 2, onTap: () => setState(() => _layout = _Layout.accents)),
        right1: _charKey('_'),
        right2: _specialKey(icon: Icons.check, onTap: _close, flex: 2, accent: true),
      ),
    ];
  }

  List<Widget> _symbolRows() {
    const row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['-', '_', '.', '/', ':', ';', '(', ')'];
    const row3 = ['@', '#', '\$', '%', '&', '*', '='];

    return [
      _row([for (final k in row1) _charKey(k)]),
      _row([for (final k in row2) _charKey(k)]),
      _row([...[for (final k in row3) _charKey(k)], _specialKey(icon: Icons.backspace_outlined, onTap: _backspace, flex: 3)]),
      _bottomRow(
        left1: _labelKey('ABC', flex: 2, onTap: () => setState(() => _layout = _Layout.letters)),
        left2: _charKey('.'),
        right1: _charKey('_'),
        right2: _specialKey(icon: Icons.check, onTap: _close, flex: 2, accent: true),
      ),
    ];
  }

  /// pt-PT's accented letters — the diacritics and cedilla that actually
  /// show up in everyday Portuguese words/names ("não", "está", "Óscar",
  /// "ação"), laid out in the same two-row-of-letters shape as
  /// [_letterRows]' own q/a rows so the layout doesn't visually jump when
  /// switching in. See [_insert] for why this layout is one-shot.
  List<Widget> _accentRows() {
    const row1 = ['á', 'à', 'â', 'ã', 'é', 'ê', 'í'];
    const row2 = ['ó', 'ô', 'õ', 'ú', 'ç'];

    return [
      _row([for (final k in row1) _charKey(_cased(k))]),
      _row([const SizedBox(width: 68), ...[for (final k in row2) _charKey(_cased(k))], const SizedBox(width: 68)]),
      _row([
        _specialKey(icon: Icons.arrow_upward, active: _shift, onTap: () => setState(() => _shift = !_shift), flex: 4),
        _specialKey(icon: Icons.backspace_outlined, onTap: _backspace, flex: 4),
      ]),
      _bottomRow(
        left1: _labelKey('ABC', flex: 2, onTap: () => setState(() => _layout = _Layout.letters)),
        left2: _charKey('.'),
        right1: _charKey('_'),
        right2: _specialKey(icon: Icons.check, onTap: _close, flex: 2, accent: true),
      ),
    ];
  }

  Widget _row(List<Widget> keys) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: keys));
  }

  Widget _charKey(String char) {
    return _KeyButton(flex: 3, onTap: () => _insert(char), child: Text(char, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)));
  }

  Widget _labelKey(String label, {required int flex, required VoidCallback onTap}) {
    return _KeyButton(
      flex: flex,
      onTap: onTap,
      background: NocturneColors.neutral800,
      child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
    );
  }

  Widget _specialKey({required IconData icon, required VoidCallback onTap, int flex = 3, bool active = false, bool accent = false}) {
    return _KeyButton(
      flex: flex,
      onTap: onTap,
      background: accent
          ? NocturneColors.accent.withValues(alpha: 0.25)
          : active
          ? NocturneColors.accent.withValues(alpha: 0.18)
          : NocturneColors.neutral800,
      child: Icon(icon, size: 24, color: accent || active ? NocturneColors.accent : NocturneColors.text),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.flex, required this.onTap, required this.child, this.background});

  final int flex;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: background ?? NocturneColors.neutral900,
          borderRadius: BorderRadius.circular(NocturneRadii.chip),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(NocturneRadii.chip),
            child: SizedBox(height: 64, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
