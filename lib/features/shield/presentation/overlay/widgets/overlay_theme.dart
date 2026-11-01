import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

/// Shared visual design tokens for the Hard-Lock Overlay window, mapped to [InstrumentTokens].
abstract final class OverlayTheme {
  static const Color surfaceColor = InstrumentTokens.darkBg;
  static const Color alertColor = InstrumentTokens.darkDanger;
  static const Color subtextColor = InstrumentTokens.darkInkMuted;
  static const Color actionGreen = InstrumentTokens.darkAccent;
  static const Color ink = InstrumentTokens.darkInk;
  static const Color rule = InstrumentTokens.darkRule;
  static const Color ruleStrong = InstrumentTokens.darkRuleStrong;
}
