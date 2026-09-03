import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the Energia page's `SingleChildScrollView` is actively being
/// dragged/flung — `EnergyScreen` sets this via a `ScrollNotification`
/// listener, and `EnergyFlowCard` watches it to pause its mesh ticker for
/// the duration. On constrained kiosk hardware, a continuously-repainting
/// mesh competing with the scroll gesture for the same per-frame budget is
/// what actually caused the scroll itself to visibly stutter — pausing the
/// mesh (silently, since a moving list of nodes/dots isn't something anyone
/// is watching closely mid-scroll anyway) frees that budget back up.
final energyPageScrollingProvider = StateProvider<bool>((ref) => false);
