import 'package:flutter/material.dart';

/// Colour tokens for the 22" vertical kiosk redesign ("Calendário Familiar +
/// Casa Inteligente"). Unlike `NocturneColors`, these are plain `const`s:
/// the redesign has a single light look, so nothing here needs to re-read
/// a theme mode at call time.
abstract final class KColors {
  static const page = Color(0xFFF3F1EC);
  static const card = Color(0xFFFFFFFF);
  static const sub = Color(0xFFF7F5F1);
  static const ink = Color(0xFF17191C);
  static const muted = Color(0xFF5F646B);
  static const ink2 = Color(0xFF3B4046);
  static const ink3 = Color(0xFF4A4F55);
  static const faint = Color(0xFF7A7F86);
  static const faint2 = Color(0xFF9A9EA4);
  static const border = Color(0xFFE3DFD6);
  static const divider = Color(0xFFEFECE6);
  static const navBorder = Color(0xFFE6E2DA);
  static const ring = Color(0xFFC9C4BA);
  static const dashed = Color(0xFFD6D1C7);
  static const disabledFg = Color(0xFFB9B4AA);
  static const chip = Color(0xFFF3F1EC);
  static const chipAlt = Color(0xFFEFECE6);

  static const accent = Color(0xFF1F4D45);
  static const accentSoft = Color(0xFFE6EFEC);
  static const onAccentMuted = Color(0xFFD5E3DF);

  static const todayBg = Color(0xFFFBF3EC);
  static const todayInk = Color(0xFF9A3412);
  static const todayBorder = Color(0xFFF1D3BE);
  static const now = Color(0xFFC2410C);

  static const red = Color(0xFFB42318);
  static const redInk = Color(0xFF912018);
  static const redTint = Color(0xFFFDE8E7);
  static const holidayBg = Color(0xFFFEF6F5);

  static const green = Color(0xFF2B8A3E);
  static const greenInk = Color(0xFF1E5E2B);
  static const greenTint = Color(0xFFE1F3E5);

  static const blue = Color(0xFF1864AB);
  static const blueTint = Color(0xFFE1EEFB);

  static const orange = Color(0xFFC2410C);
  static const orangeInk = Color(0xFF9A3412);
  static const orangeTint = Color(0xFFFDEBDD);

  static const purple = Color(0xFF5F3DC4);
  static const purpleTint = Color(0xFFECE7FD);

  static const pink = Color(0xFFC2255C);
  static const pinkInk = Color(0xFFA61E4D);
  static const pinkTint = Color(0xFFFCE7EF);

  static const amber = Color(0xFFE8A33A);
  static const amberTint = Color(0xFFFFF1D6);
  static const amberInk = Color(0xFF7A4A00);

  static const lightRoomBg = Color(0xFFFFF8EA);
  static const lightBtnBg = Color(0xFFFFE9BF);
  static const lightIconBg = Color(0xFFF2A93B);
  static const lightIconFg = Color(0xFF3D2600);

  static const camera = Color(0xFF2C3036);
  static const cameraText = Color(0xFFC9CDD2);
  static const dark = Color(0xFF17191C);

  static const keyboardBg = Color(0xFFE4E0D8);
  static const keyboardFunc = Color(0xFFCFCAC0);

  static const scrim = Color(0x8017191C);
}

/// The person/calendar palette — one hue each for a family member, a
/// calendar, a task owner. Keyed by the names the sidebar panel stores in
/// HA (`blue`/`amber`/`green`/`accent`/`pink`). People get pink rather than
/// red so nobody reads as a holiday; an older saved `red` maps to pink too.
/// [red] stays for holiday calendars.
class KPersonColor {
  const KPersonColor(this.color, this.tint, this.ink);

  final Color color;
  final Color tint;
  final Color ink;

  static const blue = KPersonColor(KColors.blue, KColors.blueTint, KColors.blue);
  static const orange = KPersonColor(KColors.orange, KColors.orangeTint, KColors.orangeInk);
  static const green = KPersonColor(KColors.green, KColors.greenTint, KColors.greenInk);
  static const purple = KPersonColor(KColors.purple, KColors.purpleTint, KColors.purple);
  static const red = KPersonColor(KColors.red, KColors.redTint, KColors.redInk);
  static const pink = KPersonColor(KColors.pink, KColors.pinkTint, KColors.pinkInk);

  static const cycle = [blue, orange, green, purple, pink];

  static KPersonColor fromKey(String? key) => switch (key) {
    'blue' => blue,
    'amber' || 'orange' => orange,
    'green' => green,
    'pink' || 'red' => pink,
    'accent' || 'purple' => purple,
    _ => blue,
  };
}

/// Type styles from the design's "Regras de escala" board. Sizes are in
/// design pixels — the whole UI is laid out on a fixed 1440-wide canvas
/// (see `KioskCanvas`), so these never need scaling at call sites.
abstract final class KText {
  static const sans = 'DM Sans';
  static const display = 'Outfit';

  static TextStyle s(double size, {FontWeight weight = FontWeight.w400, Color color = KColors.ink, double? height, double? spacing}) =>
      TextStyle(fontFamily: sans, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing, decoration: TextDecoration.none);

  static TextStyle d(double size, {FontWeight weight = FontWeight.w500, Color color = KColors.ink, double? height, double? spacing}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing, decoration: TextDecoration.none);

  /// Small upper-case field label ("PARA QUEM", "DATA" ...).
  static TextStyle get label => s(15, weight: FontWeight.w700, color: KColors.muted, spacing: 1);

  static TextStyle get pageTitle => d(46, spacing: -1, height: 1.1);
  static TextStyle get modalTitle => d(40, spacing: -0.5);
  static TextStyle get cardTitle => d(34);
}

/// Shared motion curve — the design's `cubic-bezier(.2,.8,.2,1)`.
const kEase = Cubic(0.2, 0.8, 0.2, 1);
