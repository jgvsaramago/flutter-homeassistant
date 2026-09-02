import 'package:flutter/material.dart';

import 'theme_mode_controller.dart';

/// Design tokens for the Smart Home dashboard theme — single source of
/// truth for colour, type, radii, spacing, elevation and motion. Feature
/// code should reference these (`NocturneColors`, `NocturneRadii`,
/// `NocturneSpacing`, `NocturneDurations`, `NocturneElevation`,
/// `NocturneText`) instead of literal hexes/radii/durations.
///
/// Values here are transcribed directly from the project's `theme.css`/
/// `theme-light.css` — treat those files as the source of truth if they
/// ever disagree with this one again; this file exists only because Dart
/// has no `var(--*)`.
///
/// [NocturneColors]/[NocturneText]/[NocturneElevation] read
/// [ThemeModeController.instance] to decide dark vs light at *call* time —
/// each is a `static Color get`, not a `static const`, specifically so a
/// runtime switch (see the MQTT `select` entity in
/// `pi_telemetry_publisher_io.dart`) can actually change what they return.
/// [NocturneRadii]/[NocturneSpacing]/[NocturneDurations] stay plain
/// `static const`, unaffected by theme — geometry and motion are identical
/// in both palettes per the light theme's own spec ("colour-layer swap
/// only").
bool get _isLight => ThemeModeController.instance.mode.value == Brightness.light;

/// The dark palette's literal values — unchanged from before this file
/// supported a second theme. Never referenced directly outside this file;
/// [NocturneColors] is the public surface.
abstract final class _Dark {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF101114);
  static const text = Color(0xFFECECEF);

  static const accent = Color(0xFF9184D9);
  static const accent300 = Color(0xFFB3A8EA);
  static const accent400 = Color(0xFFA094E0);
  static const accent600 = Color(0xFF7A6CC9);

  static const neutral100 = Color(0xFFF4F4F6);
  static const neutral200 = Color(0xFFE0E0E5);
  static const neutral300 = Color(0xFFC6C7CC);
  static const neutral400 = Color(0xFFA7A9B0);
  static const neutral500 = Color(0xFF8A8C93);
  static const neutral600 = Color(0xFF5C5E66);
  static const neutral700 = Color(0xFF33353C);
  static const neutral800 = Color(0xFF212228);
  static const neutral900 = Color(0xFF17181C);

  /// `--color-text` at ~14% alpha.
  static const divider = Color(0x24ECECEF);

  /// rgba(0,0,0,0.62).
  static const scrim = Color(0x9E000000);

  static const solarLine = Color(0xFFCF9440);
  static const solarMark = Color(0xFFE0A44B);
  static const batteryLine = Color(0xFF4FAE7B);
  static const batteryMark = Color(0xFF62C08B);
  static const gridLine = Color(0xFF5B93CF);
  static const gridMark = Color(0xFF6EA4DD);
  static const alertLine = Color(0xFFCF6B5B);
  static const alertMark = Color(0xFFE08272);

  /// rgba(0,0,0,0.55) — navbar float shadow.
  static const navbarShadowColor = Color(0x8C000000);

  /// rgba(0,0,0,0.6) — bottom sheet shadow.
  static const sheetShadowColor = Color(0x99000000);

  /// `--color-text` at 8% alpha — navbar border.
  static const navbarBorder = Color(0x14ECECEF);

  /// Generic ambient shadow for floating elements not covered by
  /// [navbarShadowColor]/[sheetShadowColor] — rgba(0,0,0,0.55).
  static const ambientShadowColor = Color(0x8C000000);

  /// Climate hero card (Homepage) — fixed gradient, not derived from the
  /// accent token: the dark accent is too pale for a white-text surface.
  static const heroGradientStart = Color(0xFF5B4CB4);
  static const heroGradientEnd = Color(0xFF372C7C);

  /// rgba(0,0,0,0.6).
  static const heroShadowColor = Color(0x99000000);

  /// rgba(255,255,255,0.14) — the hero's inset top highlight.
  static const heroInsetHighlight = Color(0x24FFFFFF);

  /// 7-day forecast range-bar track.
  static const forecastTrack = Color(0xFF25262C);

  /// 7-day forecast cloud-icon stroke.
  static const forecastCloudStroke = Color(0xFF7D8089);
}

/// The light palette's literal values, from `theme-light.css`/
/// `theme-light-prompt.md`. Never referenced directly outside this file;
/// [NocturneColors] is the public surface.
abstract final class _Light {
  static const bg = Color(0xFFF4F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF191A20);

  static const accent = Color(0xFF6355BD);
  static const accent300 = Color(0xFF4D3FA4); // hover — darker on light, not lighter
  static const accent400 = Color(0xFF7466CB); // pressed
  static const accent600 = Color(0xFF8D80DD);

  // Neutral ramp is REVERSED vs dark: 100 is now the darkest step, 900 the
  // lightest — the same role each step plays (e.g. 800 = "idle chrome") is
  // preserved, only which literal fills that role flips.
  static const neutral100 = Color(0xFF17181C);
  static const neutral200 = Color(0xFF212228);
  static const neutral300 = Color(0xFF33353C);
  static const neutral400 = Color(0xFF5C5E66);
  static const neutral500 = Color(0xFF767881);
  static const neutral600 = Color(0xFFA7A9B0);
  static const neutral700 = Color(0xFFC6C7CC);
  static const neutral800 = Color(0xFFE2E2E7);
  static const neutral900 = Color(0xFFF0F0F3);

  /// `--color-text` at 12% alpha (`--line-hairline`).
  static const divider = Color(0x1F191A20);

  /// rgba(25,26,32,0.34) — an ink tint, not black.
  static const scrim = Color(0x57191A20);

  // Domain colours re-tuned darker for contrast on white; mark is darker
  // than line here (opposite direction from the dark theme).
  static const solarLine = Color(0xFFC98A2A);
  static const solarMark = Color(0xFFA06510);
  static const batteryLine = Color(0xFF2F9E68);
  static const batteryMark = Color(0xFF16794A);
  static const gridLine = Color(0xFF2F7CC4);
  static const gridMark = Color(0xFF2A6BAB);
  static const alertLine = Color(0xFFB8452F);
  static const alertMark = Color(0xFFA83A26);

  /// rgba(25,26,32,0.12) — navbar float shadow.
  static const navbarShadowColor = Color(0x1F191A20);

  /// rgba(25,26,32,0.14) — bottom sheet shadow.
  static const sheetShadowColor = Color(0x24191A20);

  /// `--color-text` at 7% alpha (`--line-chrome`) — navbar border.
  static const navbarBorder = Color(0x12191A20);

  /// Generic ambient shadow, per the light spec's substitution rule for any
  /// dark-theme shadow it doesn't name explicitly: same ink tint as
  /// [scrim]/[navbarShadowColor], alpha = the dark value's alpha × 0.55.
  /// 0x8C (0.549) × 0.55 ≈ 0x4D.
  static const ambientShadowColor = Color(0x4D191A20);

  /// Climate hero card — accent-derived gradient (unlike the dark theme's
  /// fixed purple: the light accent stays legible with white text).
  static const heroGradientStart = accent;
  static const heroGradientEnd = accent600;

  /// `accent` at 45% alpha (`color-mix(in srgb, accent 45%, transparent)`).
  static const heroShadowColor = Color(0x736355BD);

  /// rgba(255,255,255,0.25) — the hero's inset top highlight.
  static const heroInsetHighlight = Color(0x40FFFFFF);

  /// 7-day forecast range-bar track.
  static const forecastTrack = Color(0xFFEEEEF1);

  /// 7-day forecast cloud-icon stroke.
  static const forecastCloudStroke = Color(0xFFB9BCC6);
}

abstract final class NocturneColors {
  // Ground.
  static Color get bg => _isLight ? _Light.bg : _Dark.bg;
  static Color get surface => _isLight ? _Light.surface : _Dark.surface;
  static Color get text => _isLight ? _Light.text : _Dark.text;

  /// A panel drawn inside a card (`--color-inset`) — same value as
  /// [neutral900], named separately because it's a *role* (the third and
  /// last background allowed on a screen, alongside [bg] and [surface]),
  /// not a point on the neutral ramp.
  static Color get inset => neutral900;

  // Accent — blurple, used for lines, labels, active states, glows. Never
  // a flood fill.
  static Color get accent => _isLight ? _Light.accent : _Dark.accent;
  static Color get accent300 => _isLight ? _Light.accent300 : _Dark.accent300; // hover / links hover
  static Color get accent400 => _isLight ? _Light.accent400 : _Dark.accent400; // pressed
  static Color get accent600 => _isLight ? _Light.accent600 : _Dark.accent600;

  /// Kept for call sites that pre-date `accent300`; identical value.
  static Color get accent2 => accent300;

  // Neutral ramp — untinted, light -> dark in the dark theme; REVERSED in
  // the light theme (see `_Light`'s comment), so the role each step plays
  // stays put across both.
  static Color get neutral100 => _isLight ? _Light.neutral100 : _Dark.neutral100;
  static Color get neutral200 => _isLight ? _Light.neutral200 : _Dark.neutral200;
  static Color get neutral300 => _isLight ? _Light.neutral300 : _Dark.neutral300;
  static Color get neutral400 => _isLight ? _Light.neutral400 : _Dark.neutral400;
  static Color get neutral500 => _isLight ? _Light.neutral500 : _Dark.neutral500;
  static Color get neutral600 => _isLight ? _Light.neutral600 : _Dark.neutral600;
  static Color get neutral700 => _isLight ? _Light.neutral700 : _Dark.neutral700;
  static Color get neutral800 => _isLight ? _Light.neutral800 : _Dark.neutral800;
  static Color get neutral900 => _isLight ? _Light.neutral900 : _Dark.neutral900;

  /// Hairline divider: `text` at low alpha.
  static Color get divider => _isLight ? _Light.divider : _Dark.divider;

  /// Scrim behind a bottom sheet / modal barrier.
  static Color get scrim => _isLight ? _Light.scrim : _Dark.scrim;

  // Domain colours: each has a duller "line" (strokes, bars, flow paths)
  // and a brighter-on-dark/darker-on-light "mark" (icons, numerals, badges,
  // pills). These are also the app's general semantic hues beyond energy
  // specifically — solar covers warm/lights, ok/battery covers
  // ok/climate-ok, cool/grid covers cool/water, alert covers
  // errors/worst-case thresholds — so `amber`/`blue`/`green`/`red` below
  // alias the matching "mark" tone for existing call sites that predate the
  // named domain tokens.
  static Color get solarLine => _isLight ? _Light.solarLine : _Dark.solarLine;
  static Color get solarMark => _isLight ? _Light.solarMark : _Dark.solarMark;
  static Color get batteryLine => _isLight ? _Light.batteryLine : _Dark.batteryLine;
  static Color get batteryMark => _isLight ? _Light.batteryMark : _Dark.batteryMark;
  static Color get gridLine => _isLight ? _Light.gridLine : _Dark.gridLine;
  static Color get gridMark => _isLight ? _Light.gridMark : _Dark.gridMark;
  static Color get alertLine => _isLight ? _Light.alertLine : _Dark.alertLine;
  static Color get alertMark => _isLight ? _Light.alertMark : _Dark.alertMark;

  static Color get amber => solarMark;
  static Color get blue => gridMark;
  static Color get green => batteryMark;

  /// The app's one error/bad-state hue, e.g. `ColorScheme.error` below and
  /// the worst CO2 threshold — aliases the alert domain's mark tone.
  static Color get red => alertMark;

  // Homepage climate hero card (see `ClimateHero`).
  static Color get heroGradientStart => _isLight ? _Light.heroGradientStart : _Dark.heroGradientStart;
  static Color get heroGradientEnd => _isLight ? _Light.heroGradientEnd : _Dark.heroGradientEnd;
  static Color get heroShadowColor => _isLight ? _Light.heroShadowColor : _Dark.heroShadowColor;
  static Color get heroInsetHighlight => _isLight ? _Light.heroInsetHighlight : _Dark.heroInsetHighlight;

  // 7-day forecast range-bar chart (see `WeeklyForecastCard`).
  static Color get forecastTrack => _isLight ? _Light.forecastTrack : _Dark.forecastTrack;
  static Color get forecastCloudStroke => _isLight ? _Light.forecastCloudStroke : _Dark.forecastCloudStroke;
}

/// Radius scale — pick from these, nothing between. Unaffected by theme.
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
/// `*Gap` tokens below when laying out an actual surface. Unaffected by
/// theme.
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

/// Motion durations/curves from the spec. Unaffected by theme.
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

/// Elevation: on dark, an edge plus ambient darkness; on light, an edge
/// plus a soft ink shadow (never black) — see `_Dark`/`_Light`'s shadow
/// colours. Never stack heavy shadows either way.
abstract final class NocturneElevation {
  static BoxShadow get navbarShadow =>
      BoxShadow(color: _isLight ? _Light.navbarShadowColor : _Dark.navbarShadowColor, blurRadius: _isLight ? 30 : 40, offset: Offset(0, _isLight ? 10 : 16));
  static BoxShadow get sheetShadow =>
      BoxShadow(color: _isLight ? _Light.sheetShadowColor : _Dark.sheetShadowColor, blurRadius: 60, offset: const Offset(0, -20));
  static Color get navbarBorder => _isLight ? _Light.navbarBorder : _Dark.navbarBorder;

  /// A generic ambient shadow colour for floating elements not covered by
  /// [navbarShadow]/[sheetShadow] (the on-screen keyboard, a sheet's
  /// metric-grid header) — same substitution the light theme spec gives for
  /// shadows it doesn't call out by name.
  static Color get ambientShadowColor => _isLight ? _Light.ambientShadowColor : _Dark.ambientShadowColor;

  /// A circular node overlapping a connector line gets a punch-out ring in
  /// the surface colour behind it, so the line appears to stop at its edge.
  static List<BoxShadow> nodePunchout({Color? color, bool small = false}) =>
      [BoxShadow(color: color ?? NocturneColors.surface, spreadRadius: small ? 5 : 8)];
}

/// Type roles from the spec's hierarchy table. Hierarchy is size and
/// space, never weight above 600. Any live-changing digit (clock,
/// temperature, duration, kWh) should merge in [tabularNums]. Sizes/weights/
/// spacing are unaffected by theme; only `color` varies.
abstract final class NocturneText {
  static const tabularNums = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

  // Every member here pins `decoration: TextDecoration.none` explicitly.
  // Without it, text rendered inside a `Sheet` (pushed via a bare
  // `PageRouteBuilder`, outside a `Scaffold`/`Card`'s own `Material`)
  // inherits an ambient underline decoration from nowhere obvious — this
  // bit the Temperatures sheet once already; pinning it here at the source
  // means no future token can reintroduce it by omission.
  static TextStyle get pageTitle =>
      TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: NocturneColors.text, letterSpacing: -0.5, decoration: TextDecoration.none);

  static TextStyle heroMetric({double size = 44}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: NocturneColors.text,
    letterSpacing: -1,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle get bigNumberSheet =>
      TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: NocturneColors.text, height: 1, decoration: TextDecoration.none);

  static TextStyle get cardKicker =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: NocturneColors.accent, letterSpacing: 1.5, decoration: TextDecoration.none);

  static TextStyle get smallKicker => TextStyle(fontSize: 13, color: NocturneColors.neutral500, letterSpacing: 1.3, decoration: TextDecoration.none);

  static TextStyle get itemTitle =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: NocturneColors.text, height: 1.2, decoration: TextDecoration.none);

  static TextStyle get body => TextStyle(fontSize: 16, color: NocturneColors.neutral400, height: 1.45, decoration: TextDecoration.none);

  static TextStyle get caption => TextStyle(fontSize: 15, color: NocturneColors.neutral500, decoration: TextDecoration.none);

  static const navLabel = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none);

  /// Baseline-aligned beside a metric (`.t-unit`).
  static TextStyle get unitSuffix => TextStyle(fontSize: 20, color: NocturneColors.neutral500, decoration: TextDecoration.none);
}

ThemeData buildNocturneTheme() {
  final light = _isLight;

  final colorScheme =
      (light
              ? ColorScheme.light(
                  primary: NocturneColors.accent,
                  onPrimary: NocturneColors.surface,
                  secondary: NocturneColors.accent300,
                  onSecondary: NocturneColors.surface,
                  surface: NocturneColors.bg,
                  onSurface: NocturneColors.text,
                  onSurfaceVariant: NocturneColors.neutral500,
                  outline: NocturneColors.neutral700,
                  outlineVariant: NocturneColors.divider,
                  error: NocturneColors.red,
                )
              : ColorScheme.dark(
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
                ))
          .copyWith(surfaceContainer: NocturneColors.surface, surfaceContainerHigh: NocturneColors.surface, surfaceContainerHighest: NocturneColors.neutral800);

  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true, brightness: light ? Brightness.light : Brightness.dark);

  return base.copyWith(
    scaffoldBackgroundColor: NocturneColors.bg,
    canvasColor: NocturneColors.bg,
    dividerColor: NocturneColors.divider,
    textTheme: base.textTheme.apply(bodyColor: NocturneColors.text, displayColor: NocturneColors.text),
    iconTheme: IconThemeData(color: NocturneColors.text),
    cardTheme: CardThemeData(
      color: NocturneColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NocturneRadii.primaryCard))),
    ),
    appBarTheme: AppBarTheme(backgroundColor: NocturneColors.bg, foregroundColor: NocturneColors.text, elevation: 0),
    // This app only ever runs on a fixed kiosk touchscreen — long-press's
    // default "hover" tooltip popup (Flutter's stand-in for a desktop mouse
    // hover, see Tooltip's own default) has no discoverability purpose here
    // and just reads as a stray popup appearing under a held finger.
    // `tooltip:` strings on buttons stay in place for semantics; this only
    // suppresses the visual popup they'd otherwise trigger on long-press.
    tooltipTheme: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
  );
}
