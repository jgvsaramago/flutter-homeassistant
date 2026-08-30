import 'package:flutter/material.dart';

/// Design tokens for the Smart Home dashboard theme — single source of
/// truth for colour, type, radii, spacing, elevation and motion. Feature
/// code should reference these (`NocturneColors`, `NocturneRadii`,
/// `NocturneSpacing`, `NocturneDurations`, `NocturneElevation`,
/// `NocturneText`) instead of literal hexes/radii/durations.
///
/// Values here are transcribed directly from the project's `theme.css` —
/// treat that file as the source of truth if the two ever disagree again;
/// this file exists only because Dart has no `var(--*)`.
///
/// This overrides the underlying Nocturne design system's ground to pure
/// black with untinted greys, for OLED wall panels in a dark room. Inter is
/// the spec'd typeface, but no Inter asset is bundled (this is a headless
/// kiosk with no guaranteed network access, so a runtime font download
/// isn't appropriate) — text falls back to the platform default family.
abstract final class NocturneColors {
  // Ground.
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF101114);
  static const text = Color(0xFFECECEF);

  /// A panel drawn inside a card (`--color-inset`) — same value as
  /// [neutral900], named separately because it's a *role* (the third and
  /// last background allowed on a screen, alongside [bg] and [surface]),
  /// not a point on the neutral ramp.
  static const inset = neutral900;

  // Accent — blurple, used for lines, labels, active states, glows. Never
  // a flood fill.
  static const accent = Color(0xFF9184D9);
  static const accent300 = Color(0xFFB3A8EA); // hover / links hover
  static const accent400 = Color(0xFFA094E0); // pressed (on this dark ground)
  static const accent600 = Color(0xFF7A6CC9); // pressed (on a light/tinted fill)

  /// Kept for call sites that pre-date `accent300`; identical value.
  static const accent2 = accent300;

  // Neutral ramp — untinted, light -> dark.
  static const neutral100 = Color(0xFFF4F4F6);
  static const neutral200 = Color(0xFFE0E0E5);
  static const neutral300 = Color(0xFFC6C7CC);
  static const neutral400 = Color(0xFFA7A9B0);
  static const neutral500 = Color(0xFF8A8C93);
  static const neutral600 = Color(0xFF5C5E66);
  static const neutral700 = Color(0xFF33353C);
  static const neutral800 = Color(0xFF212228);
  static const neutral900 = Color(0xFF17181C);

  /// Hairline divider: `text` at low alpha.
  static const divider = Color(0x24ECECEF); // ~14% alpha

  /// Scrim behind a bottom sheet / modal barrier.
  static const scrim = Color(0x9E000000); // rgba(0,0,0,0.62)

  // Domain colours: each has a duller "line" (strokes, bars, flow paths)
  // and a brighter "mark" (icons, numerals, badges, pills). These are also
  // the app's general semantic hues beyond energy specifically — solar
  // covers warm/lights, ok/battery covers ok/climate-ok, cool/grid covers
  // cool/water, alert covers errors/worst-case thresholds — so
  // `amber`/`blue`/`green`/`red` below alias the matching "mark" tone for
  // existing call sites that predate the named domain tokens.
  static const solarLine = Color(0xFFCF9440);
  static const solarMark = Color(0xFFE0A44B);
  static const batteryLine = Color(0xFF4FAE7B);
  static const batteryMark = Color(0xFF62C08B);
  static const gridLine = Color(0xFF5B93CF);
  static const gridMark = Color(0xFF6EA4DD);
  static const alertLine = Color(0xFFCF6B5B);
  static const alertMark = Color(0xFFE08272);

  static const amber = solarMark;
  static const blue = gridMark;
  static const green = batteryMark;

  /// The app's one error/bad-state hue, e.g. `ColorScheme.error` below and
  /// the worst CO2 threshold — aliases the alert domain's mark tone.
  static const red = alertMark;
}

/// Radius scale — pick from these, nothing between.
abstract final class NocturneRadii {
  static const xs = 4.0; // progress tracks, tiny bars
  static const sm = 8.0; // inline marks, mini thumbs
  static const chip = 12.0; // chips, small tiles, inset squares
  static const listRow = 16.0; // list rows, inline panels
  static const smallCard = 16.0; // small cards, mini player
  static const insetPanel = 20.0; // inset stat panels
  static const roomCard = 20.0; // room cards
  static const primaryCard = 20.0; // every card and nav pill
  static const navPill = primaryCard;
  static const floatingNavbar = 28.0;
  static const bottomSheet = 36.0; // top corners only
  static const pill = 999.0; // pills, badges, progress tracks
}

/// Spacing recipes from the spec. The raw 12-step scale (`space1`…
/// `space12`) exists for one-off gaps; prefer the composite `*Padding`/
/// `*Gap` tokens below when laying out an actual surface.
abstract final class NocturneSpacing {
  static const space1 = 4.0;
  static const space2 = 6.0;
  static const space3 = 8.0;
  static const space4 = 10.0;
  static const space5 = 12.0;
  static const space6 = 14.0;
  static const space7 = 16.0;
  static const space8 = 20.0;
  static const space9 = 24.0;
  static const space10 = 32.0;
  static const space11 = 40.0;
  static const space12 = 56.0;

  /// The navbar is a normal row in the same layout as page content (not a
  /// floating overlay), so this is just ordinary breathing room on all
  /// sides — nothing here needs to clear anything.
  static const pagePadding = EdgeInsets.fromLTRB(space8, space11, space8, space8);

  /// The default dashboard-card inset.
  static const cardPadding = EdgeInsets.symmetric(horizontal: space9, vertical: space8);
  static const compactCardPadding = EdgeInsets.symmetric(horizontal: space7, vertical: space6);
  static const rowGap = space7; // between dashboard rows
  static const cardGap = space5; // inside a card
}

/// Motion durations/curves from the spec.
abstract final class NocturneDurations {
  static const sheet = Duration(milliseconds: 320);
  static const sheetCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const colorChange = Duration(milliseconds: 200);
  static const stateCurve = Curves.ease;
  static const valueFill = Duration(milliseconds: 400);

  /// Flow particles, linear infinite (`--dur-flow`). `flowFast`/`flowSlow`
  /// are this app's own variants for flows that need to read as visibly
  /// quicker/slower than the base rate — not in the shared theme.
  static const longAction = Duration(seconds: 3);
  static const flowFast = Duration(milliseconds: 2400);
  static const flowSlow = Duration(milliseconds: 3400);
}

/// Dark-ground elevation: an edge plus ambient darkness, never a stack of
/// heavy shadows.
abstract final class NocturneElevation {
  static const navbarShadow = BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 16));
  static const sheetShadow = BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, -20));
  static const navbarBorder = Color(0x14ECECEF); // text at 8% alpha

  /// A circular node overlapping a connector line gets a punch-out ring in
  /// the surface colour behind it, so the line appears to stop at its edge.
  static List<BoxShadow> nodePunchout({Color color = NocturneColors.surface, bool small = false}) =>
      [BoxShadow(color: color, spreadRadius: small ? 5 : 8)];
}

/// Type roles from the spec's hierarchy table. Hierarchy is size and
/// space, never weight above 600. Any live-changing digit (clock,
/// temperature, duration, kWh) should merge in [tabularNums].
abstract final class NocturneText {
  static const tabularNums = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

  // Every member here pins `decoration: TextDecoration.none` explicitly.
  // Without it, text rendered inside a `Sheet` (pushed via a bare
  // `PageRouteBuilder`, outside a `Scaffold`/`Card`'s own `Material`)
  // inherits an ambient underline decoration from nowhere obvious — this
  // bit the Temperatures sheet once already; pinning it here at the source
  // means no future token can reintroduce it by omission.
  static const pageTitle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: NocturneColors.text,
    letterSpacing: -0.5,
    decoration: TextDecoration.none,
  );

  static TextStyle heroMetric({double size = 44}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: NocturneColors.text,
    letterSpacing: -1,
    height: 1,
    decoration: TextDecoration.none,
  );

  static const bigNumberSheet = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: NocturneColors.text,
    height: 1,
    decoration: TextDecoration.none,
  );

  static const cardKicker = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NocturneColors.accent,
    letterSpacing: 1.5,
    decoration: TextDecoration.none,
  );

  static const smallKicker = TextStyle(fontSize: 13, color: NocturneColors.neutral500, letterSpacing: 1.3, decoration: TextDecoration.none);

  static const itemTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: NocturneColors.text, height: 1.2, decoration: TextDecoration.none);

  static const body = TextStyle(fontSize: 16, color: NocturneColors.neutral400, height: 1.45, decoration: TextDecoration.none);

  static const caption = TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none);

  static const navLabel = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none);

  /// Baseline-aligned beside a metric (`.t-unit`).
  static const unitSuffix = TextStyle(fontSize: 20, color: NocturneColors.neutral500, decoration: TextDecoration.none);
}

ThemeData buildNocturneTheme() {
  final colorScheme = const ColorScheme.dark(
    primary: NocturneColors.accent,
    onPrimary: NocturneColors.bg,
    secondary: NocturneColors.accent300,
    onSecondary: NocturneColors.bg,
    surface: NocturneColors.bg,
    onSurface: NocturneColors.text,
    onSurfaceVariant: NocturneColors.neutral500,
    outline: NocturneColors.neutral700,
    outlineVariant: NocturneColors.divider,
    error: NocturneColors.red,
  ).copyWith(
    surfaceContainer: NocturneColors.surface,
    surfaceContainerHigh: NocturneColors.surface,
    surfaceContainerHighest: NocturneColors.neutral800,
  );

  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true, brightness: Brightness.dark);

  return base.copyWith(
    scaffoldBackgroundColor: NocturneColors.bg,
    canvasColor: NocturneColors.bg,
    dividerColor: NocturneColors.divider,
    textTheme: base.textTheme.apply(bodyColor: NocturneColors.text, displayColor: NocturneColors.text),
    iconTheme: const IconThemeData(color: NocturneColors.text),
    cardTheme: const CardThemeData(
      color: NocturneColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NocturneRadii.primaryCard))),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: NocturneColors.bg, foregroundColor: NocturneColors.text, elevation: 0),
    // This app only ever runs on a fixed kiosk touchscreen — long-press's
    // default "hover" tooltip popup (Flutter's stand-in for a desktop mouse
    // hover, see Tooltip's own default) has no discoverability purpose here
    // and just reads as a stray popup appearing under a held finger.
    // `tooltip:` strings on buttons stay in place for semantics; this only
    // suppresses the visual popup they'd otherwise trigger on long-press.
    tooltipTheme: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
  );
}
