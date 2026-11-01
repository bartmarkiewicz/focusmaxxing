import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

enum AccentFinish {
  brass(
    id: 'brass',
    displayName: 'Brass',
    subtitle: 'Classic Instrument',
    darkTokens: InstrumentTokens.darkBrass,
    lightTokens: InstrumentTokens.lightBrass,
    isProOnly: false,
  ),
  signal(
    id: 'signal',
    displayName: 'Signal',
    subtitle: 'High Visibility',
    darkTokens: InstrumentTokens.darkSignal,
    lightTokens: InstrumentTokens.lightSignal,
    isProOnly: true,
  ),
  ink(
    id: 'ink',
    displayName: 'Ink',
    subtitle: 'Muted Technical Slate',
    darkTokens: InstrumentTokens.darkInkTokens,
    lightTokens: InstrumentTokens.lightInkTokens,
    isProOnly: true,
  ),
  moss(
    id: 'moss',
    displayName: 'Moss',
    subtitle: 'Calm Field Tone',
    darkTokens: InstrumentTokens.darkMoss,
    lightTokens: InstrumentTokens.lightMoss,
    isProOnly: true,
  );

  const AccentFinish({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.darkTokens,
    required this.lightTokens,
    required this.isProOnly,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final InstrumentTokens darkTokens;
  final InstrumentTokens lightTokens;
  final bool isProOnly;

  Color get color => darkTokens.accent;
  Color get lightColor => lightTokens.accent;

  InstrumentTokens tokensFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkTokens : lightTokens;
  }

  static AccentFinish fromId(String? id) {
    if (id == null) return AccentFinish.brass;
    switch (id) {
      case 'brass':
      case 'cyber_amber':
        return AccentFinish.brass;
      case 'signal':
      case 'electric_emerald':
        return AccentFinish.signal;
      case 'ink':
      case 'hyper_violet':
        return AccentFinish.ink;
      case 'moss':
      case 'glacier_blue':
        return AccentFinish.moss;
      default:
        return AccentFinish.brass;
    }
  }
}
