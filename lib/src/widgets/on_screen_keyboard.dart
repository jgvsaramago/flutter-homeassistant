import 'package:flutter/material.dart';

import '../kiosk/theme/kiosk_icons.dart';
import '../kiosk/theme/kiosk_tokens.dart';
import 'on_screen_keyboard_controller.dart';

/// Height of the keyboard panel in design pixels (the design's "Teclado"
/// board: 96 px keys, a 68 px suggestion row, 600 px in all).
const kKeyboardHeight = 600.0;

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
/// react to either.
class OnScreenKeyboardHost extends StatefulWidget {
  const OnScreenKeyboardHost({super.key, required this.child});

  final Widget child;

  @override
  State<OnScreenKeyboardHost> createState() => _OnScreenKeyboardHostState();
}

class _OnScreenKeyboardHostState extends State<OnScreenKeyboardHost> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 220),
  );

  /// The field the panel is (or was, while sliding out) typing into — kept
  /// past detach so the exit animation still has keys to draw.
  TextEditingController? _shown;

  @override
  void initState() {
    super.initState();
    OnScreenKeyboardController.instance.active.addListener(_onActiveChanged);
    _onActiveChanged();
  }

  @override
  void dispose() {
    OnScreenKeyboardController.instance.active.removeListener(_onActiveChanged);
    _slide.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    final next = OnScreenKeyboardController.instance.active.value;
    if (next != null) {
      setState(() => _shown = next);
      _slide.forward();
    } else {
      setState(() {});
      _slide.reverse().whenComplete(() {
        if (mounted && OnScreenKeyboardController.instance.active.value == null) setState(() => _shown = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final showing = OnScreenKeyboardController.instance.active.value != null;
    final inset = showing ? kKeyboardHeight : 0.0;
    return Stack(
      children: [
        MediaQuery(
          data: mediaQuery.copyWith(
            viewInsets: mediaQuery.viewInsets.copyWith(bottom: inset > mediaQuery.viewInsets.bottom ? inset : mediaQuery.viewInsets.bottom),
          ),
          child: widget.child,
        ),
        if (_shown != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: _slide, curve: kEase, reverseCurve: Curves.easeIn)),
              // Its own layer: the slide only moves the keyboard, rather
              // than redrawing every key each frame (measured on the Pi:
              // half the dropped frames opening a modal with a text field).
              child: RepaintBoundary(child: KioskKeyboard(key: ValueKey(_shown), controller: _shown!)),
            ),
          ),
      ],
    );
  }
}

enum _Layer { abc, sym }

/// The keyboard panel itself — the design's "Teclado" component: a
/// suggestion row with a "Fechar" key, a Portuguese QWERTY with ç, dead-key
/// accents (´ ~ on letters, ^ ` on symbols) applied to the next letter, a
/// three-state shift (off → once → caps lock) and an accent "done" key
/// whose label/action the focused field chooses.
class KioskKeyboard extends StatefulWidget {
  const KioskKeyboard({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<KioskKeyboard> createState() => _KioskKeyboardState();
}

class _KioskKeyboardState extends State<KioskKeyboard> {
  _Layer _layer = _Layer.abc;

  /// 0 = off, 1 = next letter only, 2 = caps lock.
  int _shift = 0;
  String? _dead;

  static const _accents = {
    '´': {'a': 'á', 'e': 'é', 'i': 'í', 'o': 'ó', 'u': 'ú'},
    '`': {'a': 'à', 'e': 'è', 'i': 'ì', 'o': 'ò', 'u': 'ù'},
    '^': {'a': 'â', 'e': 'ê', 'i': 'î', 'o': 'ô', 'u': 'û'},
    '~': {'a': 'ã', 'o': 'õ', 'n': 'ñ'},
  };

  KeyboardOptions get _options => OnScreenKeyboardController.instance.options;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  /// Auto-capitalise at the start of the field or a new sentence.
  bool get _capNext {
    if (!_options.capitalize || _layer != _Layer.abc) return false;
    final text = widget.controller.text;
    return text.isEmpty || RegExp(r'[.!?]\s$').hasMatch(text);
  }

  bool get _upper => _shift > 0 || (_shift == 0 && _capNext);

  void _insert(String text) {
    final value = widget.controller.value;
    var selection = value.selection;
    if (!selection.isValid) selection = TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(selection.start, selection.end, text);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  void _type(String ch) {
    var out = ch;
    if (_dead != null) out = _accents[_dead]![ch] ?? '$_dead$ch';
    if (_upper) out = out.toUpperCase();
    _insert(out);
    setState(() {
      _dead = null;
      if (_shift == 1) _shift = 0;
    });
  }

  void _deadKey(String accent) {
    if (_dead == accent) {
      _insert(accent);
      setState(() => _dead = null);
    } else {
      setState(() => _dead = accent);
    }
  }

  void _space() {
    _insert(_dead != null ? '$_dead ' : ' ');
    setState(() => _dead = null);
  }

  void _backspace() {
    final value = widget.controller.value;
    var selection = value.selection;
    if (!selection.isValid) selection = TextSelection.collapsed(offset: value.text.length);
    if (selection.start != selection.end) {
      _insert('');
      return;
    }
    final start = selection.start;
    if (start <= 0) return;
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(start - 1, start, ''),
      selection: TextSelection.collapsed(offset: start - 1),
    );
  }

  void _done() {
    final onDone = _options.onDone;
    if (onDone != null) {
      onDone();
    } else {
      OnScreenKeyboardController.instance.close();
    }
  }

  void _suggest(String s) {
    final onSuggest = _options.onSuggest;
    if (onSuggest != null) {
      onSuggest(s);
    } else {
      widget.controller.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _options.suggestions?.call(widget.controller.text) ?? const <String>[];
    // TextFieldTapRegion marks this panel as part of the focused field's own
    // tap region even though it's mounted at the app root, entirely outside
    // that field's widget subtree — the same mechanism a real IME's
    // predictive-text bar uses. Without it, a key tap here would register as
    // "tapped outside the field" and blur it, dropping the keystroke.
    return TextFieldTapRegion(
      child: Container(
        height: kKeyboardHeight,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: KColors.keyboardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [BoxShadow(color: Color(0x1F17191C), blurRadius: 30, offset: Offset(0, -10))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: Row(
                          children: [
                            for (final s in suggestions.take(6)) ...[
                              _Pressable(
                                onTap: () => _suggest(s),
                                child: Container(
                                  height: 68,
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(34)),
                                  child: Text(s, maxLines: 1, style: KText.s(24, weight: FontWeight.w500)),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _Pressable(
                      onTap: () => OnScreenKeyboardController.instance.close(),
                      child: Container(
                        height: 68,
                        padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
                        decoration: BoxDecoration(color: KColors.keyboardFunc, borderRadius: BorderRadius.circular(34)),
                        child: Row(
                          children: [
                            Text('Fechar', style: KText.s(22, weight: FontWeight.w600)),
                            const SizedBox(width: 10),
                            const KIcon(KIcons.keyboard, size: 30, stroke: 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._rows().expand((row) => [row, const SizedBox(height: 12)]).toList()..removeLast(),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows() {
    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[if (i > 0) const SizedBox(width: 12), keys[i]],
      ],
    );
    final space = _key(label: 'espaço', flex: 5, size: 24, fg: KColors.muted, onTap: _space);
    final done = _key(label: _options.doneLabel, flex: 2.2, size: 24, weight: FontWeight.w600, bg: KColors.accent, fg: Colors.white, onTap: _done);
    final back = _key(icon: KIcons.backspace, flex: 1.5, bg: KColors.keyboardFunc, onTap: _backspace);
    if (_layer == _Layer.abc) {
      final shiftBg = _shift == 2 ? KColors.ink : (_upper ? Colors.white : KColors.keyboardFunc);
      final shiftFg = _shift == 2 ? Colors.white : KColors.ink;
      return [
        row([for (final c in 'qwertyuiop'.split('')) _letter(c)]),
        row([for (final c in 'asdfghjklç'.split('')) _letter(c)]),
        row([
          _key(icon: KIcons.shift, iconFilled: _upper, flex: 1.5, bg: shiftBg, fg: shiftFg, onTap: () => setState(() => _shift = (_shift + 1) % 3)),
          for (final c in 'zxcvbnm'.split('')) _letter(c),
          back,
        ]),
        row([
          _key(
            label: '123',
            flex: 1.5,
            size: 24,
            weight: FontWeight.w600,
            bg: KColors.keyboardFunc,
            onTap: () => setState(() {
              _layer = _Layer.sym;
              _dead = null;
            }),
          ),
          _dead2('´'),
          _dead2('~'),
          space,
          _sym(','),
          _sym('.'),
          done,
        ]),
      ];
    }
    return [
      row([for (final c in '1234567890'.split('')) _sym(c)]),
      row([
        for (final c in ['@', '€', '&', '(', ')', '-', '/', ':', ';', '"']) _sym(c),
      ]),
      row([
        _dead2('^'),
        _dead2('`'),
        for (final c in ['!', '?', "'", '#', '%', '+', '=']) _sym(c),
        back,
      ]),
      row([
        _key(
          label: 'ABC',
          flex: 1.5,
          size: 24,
          weight: FontWeight.w600,
          bg: KColors.keyboardFunc,
          onTap: () => setState(() {
            _layer = _Layer.abc;
            _dead = null;
          }),
        ),
        _dead2('´'),
        _dead2('~'),
        space,
        _sym(','),
        _sym('.'),
        done,
      ]),
    ];
  }

  Widget _letter(String c) => _key(label: _upper ? c.toUpperCase() : c, onTap: () => _type(c));

  Widget _sym(String c) => _key(label: c, onTap: () => _type(c));

  Widget _dead2(String accent) {
    final on = _dead == accent;
    return _key(label: accent, bg: on ? KColors.accent : Colors.white, fg: on ? Colors.white : KColors.ink, onTap: () => _deadKey(accent));
  }

  Widget _key({
    String? label,
    String? icon,
    bool iconFilled = false,
    double flex = 1,
    double size = 34,
    FontWeight weight = FontWeight.w500,
    Color bg = Colors.white,
    Color fg = KColors.ink,
    required VoidCallback onTap,
  }) {
    return Expanded(
      flex: (flex * 10).round(),
      child: _KeyPress(
        onTap: onTap,
        child: Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x2417191C), offset: Offset(0, 2))],
          ),
          child: icon != null
              ? KIcon(icon, size: 42, color: fg, stroke: 1.8, filled: iconFilled)
              : Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: KText.s(size, weight: weight, color: fg),
                ),
        ),
      ),
    );
  }
}

/// Key press feedback: the design's `button:active { transform: scale(.96) }`.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? 0.96 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

/// Key press feedback from the design's keyboard: a key darkens the moment
/// it's touched (`filter: brightness(.78)`, no shrink) and fades back over
/// 200 ms once released, like a phone keyboard. Taps shorter than a frame
/// or two still show a visible flash.
class _KeyPress extends StatefulWidget {
  const _KeyPress({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_KeyPress> createState() => _KeyPressState();
}

class _KeyPressState extends State<_KeyPress> {
  static const _minFlash = Duration(milliseconds: 70);

  bool _down = false;
  DateTime _downAt = DateTime(0);

  void _press() {
    _downAt = DateTime.now();
    setState(() => _down = true);
  }

  void _release() {
    final held = DateTime.now().difference(_downAt);
    if (held >= _minFlash) {
      if (mounted) setState(() => _down = false);
    } else {
      Future<void>.delayed(_minFlash - held, () {
        if (mounted) setState(() => _down = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _down ? 0.78 : 1.0),
        duration: _down ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.ease,
        builder: (context, f, child) =>
            ColorFiltered(colorFilter: ColorFilter.matrix([f, 0, 0, 0, 0, 0, f, 0, 0, 0, 0, 0, f, 0, 0, 0, 0, 0, 1, 0]), child: child),
        child: widget.child,
      ),
    );
  }
}
