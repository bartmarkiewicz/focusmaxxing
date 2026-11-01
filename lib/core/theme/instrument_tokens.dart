import 'package:flutter/material.dart';

/// Design tokens representing "The Instrument" physical design aesthetic.
/// Registered as a [ThemeExtension] on ThemeData and available via context.
@immutable
class InstrumentTokens extends ThemeExtension<InstrumentTokens> {
  const InstrumentTokens({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.rule,
    required this.ruleStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.accentInk,
    required this.danger,
    required this.ok,
  });

  // Base Spacing Scale
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;
  static const double gutter = 20.0;
  static const double rowHeight = 56.0;

  // Corner Radii
  static const double r0 = 0.0;
  static const double r1 = 4.0;
  static const double r2 = 8.0;
  static const double r3 = 16.0;

  // Motion Durations & Curves
  static const Duration tickDuration = Duration(milliseconds: 90);
  static const Curve tickCurve = Curves.easeOut;

  static const Duration moveDuration = Duration(milliseconds: 200);
  static const Curve moveCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  static const Duration settleDuration = Duration(milliseconds: 320);
  static const Curve settleCurve = Cubic(0.3, 0.0, 0.0, 1.0);

  // Typography Families
  static const String fontUi = 'InterTight';
  static const String fontMono = 'JetBrainsMono';

  // Constant Raw Colors
  static const Color darkBg = Color(0xFF121110);
  static const Color darkSurface = Color(0xFF1A1917);
  static const Color darkSurfaceSunken = Color(0xFF0D0C0B);
  static const Color darkRule = Color(0xFF2A2825);
  static const Color darkRuleStrong = Color(0xFF3A3733);
  static const Color darkInk = Color(0xFFEDE9E3);
  static const Color darkInkMuted = Color(0xFF9A948B);
  static const Color darkInkFaint = Color(0xFF5E5A54);
  static const Color darkAccentBrass = Color(0xFFC9A227);
  static const Color darkAccent = darkAccentBrass;
  static const Color darkAccentSignal = Color(0xFFFF5A1F);
  static const Color darkAccentInk = Color(0xFF8FA3BF);
  static const Color darkAccentMoss = Color(0xFF8DA67A);
  static const Color darkAccentInkText = Color(0xFF121110);
  static const Color darkDanger = Color(0xFFE5484D);
  static const Color darkOk = Color(0xFF7FB685);

  static const Color lightBg = Color(0xFFF4F1EC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSunken = Color(0xFFEAE6DF);
  static const Color lightRule = Color(0xFFE2DDD5);
  static const Color lightRuleStrong = Color(0xFFCFC8BD);
  static const Color lightInk = Color(0xFF1A1917);
  static const Color lightInkMuted = Color(0xFF6B665E);
  static const Color lightInkFaint = Color(0xFF9A948B);
  static const Color lightAccentBrass = Color(0xFF8A6A0E);
  static const Color lightAccentSignal = Color(0xFFC2410C);
  static const Color lightAccentInk = Color(0xFF3E5675);
  static const Color lightAccentMoss = Color(0xFF4F6B3C);
  static const Color lightAccentInkText = Color(0xFFFFFFFF);
  static const Color lightDanger = Color(0xFFC62F35);
  static const Color lightOk = Color(0xFF4F7A55);

  // Colors
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color rule;
  final Color ruleStrong;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color accent;
  final Color accentInk;
  final Color danger;
  final Color ok;

  // Static standard token presets for overlay and direct const access
  static const InstrumentTokens darkBrass = InstrumentTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceSunken: darkSurfaceSunken,
    rule: darkRule,
    ruleStrong: darkRuleStrong,
    ink: darkInk,
    inkMuted: darkInkMuted,
    inkFaint: darkInkFaint,
    accent: darkAccentBrass,
    accentInk: darkAccentInkText,
    danger: darkDanger,
    ok: darkOk,
  );

  static const InstrumentTokens darkSignal = InstrumentTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceSunken: darkSurfaceSunken,
    rule: darkRule,
    ruleStrong: darkRuleStrong,
    ink: darkInk,
    inkMuted: darkInkMuted,
    inkFaint: darkInkFaint,
    accent: darkAccentSignal,
    accentInk: darkAccentInkText,
    danger: darkDanger,
    ok: darkOk,
  );

  static const InstrumentTokens darkInkTokens = InstrumentTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceSunken: darkSurfaceSunken,
    rule: darkRule,
    ruleStrong: darkRuleStrong,
    ink: darkInk,
    inkMuted: darkInkMuted,
    inkFaint: darkInkFaint,
    accent: darkAccentInk,
    accentInk: darkAccentInkText,
    danger: darkDanger,
    ok: darkOk,
  );

  static const InstrumentTokens darkMoss = InstrumentTokens(
    bg: darkBg,
    surface: darkSurface,
    surfaceSunken: darkSurfaceSunken,
    rule: darkRule,
    ruleStrong: darkRuleStrong,
    ink: darkInk,
    inkMuted: darkInkMuted,
    inkFaint: darkInkFaint,
    accent: darkAccentMoss,
    accentInk: darkAccentInkText,
    danger: darkDanger,
    ok: darkOk,
  );

  static const InstrumentTokens lightBrass = InstrumentTokens(
    bg: lightBg,
    surface: lightSurface,
    surfaceSunken: lightSurfaceSunken,
    rule: lightRule,
    ruleStrong: lightRuleStrong,
    ink: lightInk,
    inkMuted: lightInkMuted,
    inkFaint: lightInkFaint,
    accent: lightAccentBrass,
    accentInk: lightAccentInkText,
    danger: lightDanger,
    ok: lightOk,
  );

  static const InstrumentTokens lightSignal = InstrumentTokens(
    bg: lightBg,
    surface: lightSurface,
    surfaceSunken: lightSurfaceSunken,
    rule: lightRule,
    ruleStrong: lightRuleStrong,
    ink: lightInk,
    inkMuted: lightInkMuted,
    inkFaint: lightInkFaint,
    accent: lightAccentSignal,
    accentInk: lightAccentInkText,
    danger: lightDanger,
    ok: lightOk,
  );

  static const InstrumentTokens lightInkTokens = InstrumentTokens(
    bg: lightBg,
    surface: lightSurface,
    surfaceSunken: lightSurfaceSunken,
    rule: lightRule,
    ruleStrong: lightRuleStrong,
    ink: lightInk,
    inkMuted: lightInkMuted,
    inkFaint: lightInkFaint,
    accent: lightAccentInk,
    accentInk: lightAccentInkText,
    danger: lightDanger,
    ok: lightOk,
  );

  static const InstrumentTokens lightMoss = InstrumentTokens(
    bg: lightBg,
    surface: lightSurface,
    surfaceSunken: lightSurfaceSunken,
    rule: lightRule,
    ruleStrong: lightRuleStrong,
    ink: lightInk,
    inkMuted: lightInkMuted,
    inkFaint: lightInkFaint,
    accent: lightAccentMoss,
    accentInk: lightAccentInkText,
    danger: lightDanger,
    ok: lightOk,
  );

  @override
  InstrumentTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSunken,
    Color? rule,
    Color? ruleStrong,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? accent,
    Color? accentInk,
    Color? danger,
    Color? ok,
  }) {
    return InstrumentTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      rule: rule ?? this.rule,
      ruleStrong: ruleStrong ?? this.ruleStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      danger: danger ?? this.danger,
      ok: ok ?? this.ok,
    );
  }

  @override
  InstrumentTokens lerp(ThemeExtension<InstrumentTokens>? other, double t) {
    if (other is! InstrumentTokens) {
      return this;
    }
    return InstrumentTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t) ?? surfaceSunken,
      rule: Color.lerp(rule, other.rule, t) ?? rule,
      ruleStrong: Color.lerp(ruleStrong, other.ruleStrong, t) ?? ruleStrong,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t) ?? inkMuted,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t) ?? inkFaint,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentInk: Color.lerp(accentInk, other.accentInk, t) ?? accentInk,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      ok: Color.lerp(ok, other.ok, t) ?? ok,
    );
  }
}

extension InstrumentTokensContext on BuildContext {
  InstrumentTokens get tokens {
    final tokens = Theme.of(this).extension<InstrumentTokens>();
    return tokens ?? InstrumentTokens.darkBrass;
  }
}
