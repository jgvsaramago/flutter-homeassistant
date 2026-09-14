import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

/// The 4 HVAC modes the Climatização AC card exposes as chips, in display
/// order — a subset of HA's `climate` domain modes (which also has `off`,
/// `auto`/`heat_cool`) chosen to match the reference design's own 4-chip
/// row. Colours are fixed literals, not theme tokens: they read as
/// warm/cool/humid regardless of dark/light surface, same convention this
/// app already uses for the energy-flow node colours.
enum AcMode {
  cool('cool', 'Frio', 'A arrefecer', Color(0xFF2F7CC4), Color(0xFF2A6BAB), Color(0xFF84B4E6)),
  heat('heat', 'Calor', 'A aquecer', Color(0xFFC98A2A), Color(0xFFA06510), Color(0xFFE0A44B)),
  dry('dry', 'Seco', 'A desumidificar', Color(0xFF2F9E68), Color(0xFF16794A), Color(0xFF62C08B));

  const AcMode(this.hvacMode, this.label, this.verb, this.color, this.tint, this.soft);

  /// HA's `hvac_mode` value for this chip (used in `hvac_modes` and passed
  /// to `climate.set_hvac_mode`). Fan is handled separately (see [fanMode])
  /// since it's the one chip whose colour is the app's theme accent rather
  /// than a fixed literal.
  final String hvacMode;
  final String label;
  final String verb;
  final Color color;
  final Color tint;
  final Color soft;
}

/// The 4th chip — kept out of the [AcMode] enum because its colours are
/// theme-adaptive (the app's own accent), unlike the other three's fixed
/// literals; call sites that need "all 4, in order" use [allChips].
class _FanMode {
  const _FanMode();
  String get hvacMode => 'fan_only';
  String get label => 'Vent.';
  String get verb => 'Ventilação';
  Color get color => NocturneColors.accent;
  Color get tint => NocturneColors.accent;
  Color get soft => NocturneColors.accent300;
}

const fanMode = _FanMode();

/// One display-ready chip spec, unifying [AcMode] and [fanMode] so callers
/// can iterate a single list instead of special-casing fan everywhere.
class AcChipSpec {
  const AcChipSpec({required this.hvacMode, required this.label, required this.verb, required this.color, required this.tint, required this.soft});

  final String hvacMode;
  final String label;
  final String verb;
  final Color color;
  final Color tint;
  final Color soft;
}

final List<AcChipSpec> allAcChips = [
  for (final m in AcMode.values) AcChipSpec(hvacMode: m.hvacMode, label: m.label, verb: m.verb, color: m.color, tint: m.tint, soft: m.soft),
  AcChipSpec(hvacMode: fanMode.hvacMode, label: fanMode.label, verb: fanMode.verb, color: fanMode.color, tint: fanMode.tint, soft: fanMode.soft),
];

/// Looks up the chip spec for a raw HA `hvac_mode`/`state` string. Returns
/// null for a mode this card doesn't have a chip for (`heat_cool`, `auto`,
/// `off`, ...) — callers fall back to a neutral "on, mode unrecognised"
/// treatment rather than crashing on an integration this card wasn't built
/// against.
AcChipSpec? acChipFor(String hvacMode) {
  for (final chip in allAcChips) {
    if (chip.hvacMode == hvacMode) return chip;
  }
  return null;
}
