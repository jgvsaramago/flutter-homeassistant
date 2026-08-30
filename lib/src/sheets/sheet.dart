import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/nocturne_theme.dart';

/// Opens [children] as a modal sheet pinned to the bottom of the screen —
/// the abstract primitive every domain-specific sheet (Temperatures,
/// Calendar, EV, Music, Room detail) composes itself from.
///
/// Unlike a standard Flutter bottom sheet, the sheet's own window never
/// scrolls: it's a fixed-height frame, and [children] (typically taller
/// than that frame) are dragged within it via a single transform. That
/// makes one pointer gesture serve both "scroll through the content" and
/// "drag down to dismiss" — the interaction a touch-only wall panel needs,
/// where there's no separate scrollbar or edge-swipe affordance to spare.
/// See `Sheet` for exactly how that split is implemented.
Future<T?> showSheet<T>(
  BuildContext context, {
  required List<Widget> children,
  double heightPct = 0.8,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 16, 24, 40),
  double radius = 34,
  bool dismissible = true,
  bool draggableContent = true,
  Widget? footer,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: dismissible,
      barrierColor: NocturneColors.scrim,
      // Symmetric with the open animation: however the sheet is dismissed
      // (scrim tap, handle tap, or a drag past the threshold), it slides
      // back down over the same duration/curve it slid up with, rather
      // than vanishing instantly.
      transitionDuration: NocturneDurations.sheet,
      reverseTransitionDuration: NocturneDurations.sheet,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Sheet(
          animation: animation,
          onClose: () => Navigator.of(context).pop(),
          heightPct: heightPct,
          padding: padding,
          radius: radius,
          dismissible: dismissible,
          draggableContent: draggableContent,
          footer: footer,
          children: children,
        );
      },
    ),
  );
}

/// Lets a descendant of [Sheet] (chiefly [SheetHandle]) dismiss the sheet
/// without the caller having to thread an `onClose` callback through every
/// piece of content by hand.
class SheetController {
  const SheetController._(this._close);

  final VoidCallback _close;

  void close() => _close();

  static SheetController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SheetScope>();
    assert(scope != null, 'SheetController.of() called outside a Sheet.');
    return scope!.controller;
  }
}

class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.controller, required super.child});

  final SheetController controller;

  @override
  bool updateShouldNotify(_SheetScope oldWidget) => controller != oldWidget.controller;
}

/// The abstract sheet primitive. Three responsibilities, deliberately kept
/// separate (collapsing any two breaks either the animation or the drag):
///
/// - **window**: a fixed-height box pinned to the bottom of the screen.
///   [animation] (driven by the enclosing route) slides it up on open and
///   back down on close, however the close was triggered.
/// - **content**: the actual [children], laid out to their own natural
///   height (which usually exceeds the window) and moved by a single
///   `Transform.translate` — this is the piece the drag gesture controls.
/// - **scrim**: provided by the enclosing route's `barrierColor`/
///   `barrierDismissible`, not by this widget — see [showSheet].
///
/// Prefer [showSheet] over constructing this directly; it exists as its
/// own widget mainly so the drag/animation contract is independently
/// reviewable and testable.
class Sheet extends StatefulWidget {
  const Sheet({
    super.key,
    required this.animation,
    required this.onClose,
    required this.children,
    this.heightPct = 0.8,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 40),
    this.radius = 34,
    this.dismissible = true,
    this.draggableContent = true,
    this.footer,
  });

  final Animation<double> animation;
  final VoidCallback onClose;
  final List<Widget> children;
  final double heightPct;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool dismissible;
  final bool draggableContent;

  /// An optional bar pinned to the bottom of the window, outside the drag
  /// transform — unlike [children], it never moves as the content above is
  /// dragged (a persistent Agora/Explorar/Rádios tab bar, say). Callers
  /// using this should reserve matching bottom space in their own
  /// [children] (a trailing `SizedBox`) so the pinned bar never overlaps
  /// real content — this widget only pins and paints it, it doesn't know
  /// enough about the caller's content to reserve space on its behalf.
  final Widget? footer;

  @override
  State<Sheet> createState() => _SheetState();
}

class _SheetState extends State<Sheet> with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  late final AnimationController _snapController;

  double _dragOffset = 0;
  bool _dragging = false;

  /// How far the sheet must be pulled down before releasing it dismisses.
  /// Purely a release-time decision — see [_onDragEnd] — the drag itself
  /// tracks the finger exactly regardless of this value; nothing "resists"
  /// until the finger actually lifts, at which point the sheet springs
  /// either back open or the rest of the way closed.
  static const _dismissThreshold = -110.0;

  /// Deceleration for the post-release fling — the same drag coefficient
  /// [ClampingScrollPhysics] uses by default, so a released sheet coasts to
  /// a stop at the same rate anything else that scrolls in this app does.
  static const _flingFriction = 0.135;

  /// Springs a released-but-not-dismissed pull-down (offset still negative)
  /// back up to 0. Critically damped: it returns as fast as possible
  /// without overshooting past 0 into positive territory.
  static final _snapSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);

  @override
  void initState() {
    super.initState();
    // Unbounded: this controller's value is a raw pixel offset driven
    // directly by a physics [Simulation] (see [_flingToRest]), not a
    // normalized 0..1 progress — the default [0, 1] clamp would otherwise
    // flatten every real drag offset to 1.0.
    _snapController = AnimationController.unbounded(vsync: this)..addListener(_onSnapTick);
  }

  void _onSnapTick() => setState(() => _dragOffset = _snapController.value);

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double _maxDrag(double windowHeight) {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    return math.max(0.0, box.size.height - windowHeight);
  }

  void _onDragStart(DragStartDetails details) {
    _snapController.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details, double windowHeight) {
    if (!_dragging) return;
    final max = _maxDrag(windowHeight);
    // Finger moving up (negative dy) is the direction that reveals more
    // content, i.e. increases our own offset — hence the sign flip.
    var d = _dragOffset - details.delta.dy;
    // No resistance while actually dragging, in either direction — the
    // sheet tracks the finger exactly, including past the dismiss
    // threshold below 0. Whether it springs back open or springs the rest
    // of the way closed is decided once the finger lifts (_onDragEnd), not
    // during the drag itself.
    if (d > max) {
      // The one exception: fully revealed content is a hard stop, not
      // resistance — there's nothing further to reveal, so dragging past
      // `max` would just drag the content up past its own bottom edge and
      // expose whatever's behind the sheet through the gap.
      d = max;
    }
    setState(() => _dragOffset = d);
  }

  void _onDragEnd(DragEndDetails details, double windowHeight) {
    if (!_dragging) return;
    _dragging = false;
    // Same sign flip as the live update above: screen-space dy -> our
    // offset's own axis. This is the framework's own drag-gesture velocity
    // (from VerticalDragGestureRecognizer's internal VelocityTracker),
    // rather than one this widget computes by hand from raw pointer
    // events — the same primitive every scrollable in Flutter already
    // relies on for flings, including on low-sample-rate touch panels.
    final velocity = -details.velocity.pixelsPerSecond.dy;

    if (widget.dismissible && _dragOffset < _dismissThreshold) {
      // Popping the route plays its own reverse SlideTransition — a fixed
      // 320ms, velocity-blind ease from wherever `widget.animation` already
      // is. Left alone, that's *all* that moves: `_dragOffset` itself would
      // stay frozen at wherever the finger let go, so a fast dismiss swipe
      // looks like it stops dead and only then eases away on the route's
      // own fixed schedule — exactly backwards from "carries the swipe's
      // own motion". Kicking off our own unbounded fling here runs
      // alongside that route transition (this widget stays mounted for the
      // whole reverse transition) and actually carries the release
      // velocity into the exit, same as the non-dismiss case.
      _flingAway(velocity);
      widget.onClose();
      return;
    }
    _flingToRest(velocity, windowHeight);
  }

  void _onDragCancel() => _dragging = false;

  /// Continues the dismiss swipe's own motion off the bottom of the screen.
  /// Unbounded below — once dismissing, there's no floor to settle at,
  /// just further away — and only ever in the closing direction: a
  /// same-frame direction reversal right at release is rare and, if it
  /// happens, this simply leaves `_dragOffset` for the route's own
  /// transition to carry instead of animating the wrong way.
  void _flingAway(double velocity) {
    if (velocity >= 0) return;
    _snapController.animateWith(FrictionSimulation(_flingFriction, _dragOffset, velocity));
  }

  /// Settles the sheet after a release that isn't dismissing it, carrying
  /// through whatever velocity the finger had instead of snapping in from a
  /// standing start — a fast upward flick keeps gliding and decelerates
  /// naturally, exactly like flinging any other scrollable in this app,
  /// rather than freezing the instant the finger lifts and only then
  /// starting a fixed, velocity-blind ease animation.
  void _flingToRest(double velocity, double windowHeight) {
    if (_dragOffset < 0) {
      // Released mid-pull-down, but not far enough to dismiss: the offset
      // itself starts outside [0, max] here, which a clamped friction
      // simulation can't animate smoothly (it would just clamp instantly
      // to 0 on the very first frame). A spring back to 0 handles starting
      // outside the range correctly, and still carries the release
      // velocity through.
      _snapController.animateWith(SpringSimulation(_snapSpring, _dragOffset, 0, velocity));
      return;
    }
    final max = _maxDrag(windowHeight);
    _snapController.animateWith(_BoundedFrictionSimulation(position: _dragOffset, velocity: velocity, min: 0, max: max));
  }

  @override
  Widget build(BuildContext context) {
    final windowHeight = MediaQuery.sizeOf(context).height * widget.heightPct;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: widget.animation, curve: NocturneDurations.sheetCurve)),
        child: SizedBox(
          height: windowHeight,
          width: double.infinity,
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: widget.draggableContent ? _onDragStart : null,
                onVerticalDragUpdate: widget.draggableContent ? (d) => _onDragUpdate(d, windowHeight) : null,
                onVerticalDragEnd: widget.draggableContent ? (d) => _onDragEnd(d, windowHeight) : null,
                onVerticalDragCancel: widget.draggableContent ? _onDragCancel : null,
                child: Transform.translate(
                  offset: Offset(0, -_dragOffset),
                  // Without this, the Stack above hands its (non-positioned)
                  // children a *loosened* version of its own incoming
                  // constraints — same max, min forced to 0 — so the
                  // Container's `minHeight: windowHeight` below gets
                  // `enforce()`d against that max and ends up tight at
                  // exactly windowHeight, capping it there no matter how
                  // tall its content actually wants to be. Content taller
                  // than the window would then silently overflow the
                  // Column, get clipped by the Stack's own default hard
                  // edge at windowHeight, and — since `_contentKey`'s
                  // measured size was capped at windowHeight too —
                  // `_maxDrag()` would compute exactly 0: the extra content
                  // was there, cut off, with no drag able to reach it.
                  // OverflowBox reports a fixed windowHeight to the Stack
                  // (same slot as before) while still handing its own child
                  // an *uncapped* max height, so the Container can genuinely
                  // grow past the window and get measured/dragged correctly.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Container(
                      key: _contentKey,
                      width: double.infinity,
                      // Content is usually taller than the window (that's the
                      // whole reason it drags), but doesn't have to be — a sheet
                      // with genuinely little to show (an empty day, say) would
                      // otherwise paint a shorter box than the window and expose
                      // whatever's behind through the gap below it. Floors it to
                      // the window's own height so the surface always fills it.
                      constraints: BoxConstraints(minHeight: windowHeight),
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        color: NocturneColors.surface,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(widget.radius), topRight: Radius.circular(widget.radius)),
                        boxShadow: const [NocturneElevation.sheetShadow],
                      ),
                      child: _SheetScope(
                        controller: SheetController._(widget.onClose),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.footer != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    // Flush against the draggable content's own surface
                    // colour (and squared like its bottom edge already is)
                    // so the seam between "dragged" and "pinned" is invisible
                    // when the sheet is at rest.
                    decoration: const BoxDecoration(color: NocturneColors.surface),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, 16, 8, 16 + MediaQuery.paddingOf(context).bottom),
                      child: widget.footer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A friction-decelerated fling (see [Sheet._flingFriction]), hard-clamped
/// to [min]/[max] — lets a released drag's momentum carry into the settle
/// animation while still respecting the sheet's real bounds: it can't
/// scroll past fully-revealed content, and it can't settle in dismiss
/// territory once dismissing has already been ruled out for this release.
/// Clamping stops the simulation dead at the wall it hits rather than
/// bouncing off it, matching the hard-stop behaviour already decided for
/// `max` during an active drag (see `_onPointerMove`).
class _BoundedFrictionSimulation extends Simulation {
  _BoundedFrictionSimulation({required double position, required double velocity, required this.min, required this.max})
    : _friction = FrictionSimulation(_SheetState._flingFriction, position, velocity);

  final FrictionSimulation _friction;
  final double min;
  final double max;

  @override
  double x(double time) => _friction.x(time).clamp(min, max);

  @override
  double dx(double time) {
    final raw = _friction.x(time);
    return (raw <= min || raw >= max) ? 0 : _friction.dx(time);
  }

  @override
  bool isDone(double time) {
    final raw = _friction.x(time);
    return raw <= min || raw >= max || _friction.isDone(time);
  }
}
