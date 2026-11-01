import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

/// Legacy color access mapping to [InstrumentTokens].
abstract final class AppColors {
  static const Color surfaceMidnight = InstrumentTokens.darkBg;
  static const Color surfaceRaised = InstrumentTokens.darkSurface;
  static const Color surfaceHairline = InstrumentTokens.darkRule;
  static const Color surfaceElevated = InstrumentTokens.darkSurface;

  static const Color textHighContrast = InstrumentTokens.darkInk;
  static const Color textMuted = InstrumentTokens.darkInkMuted;

  static const Color accentLockIn = InstrumentTokens.darkAccentBrass;
  static const Color accentRestMode = InstrumentTokens.darkInkMuted;
  static const Color accentHardLock = InstrumentTokens.darkDanger;
  static const Color accentStreakGold = InstrumentTokens.darkAccentBrass;
}
