import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/accent_finish.dart';

export 'package:focusmaxxing/core/theme/accent_finish.dart';

/// Legacy enum adapter forwarding to [AccentFinish].
enum ProAccentVariant {
  electricEmerald(
    id: 'signal',
    displayName: 'Signal',
    subtitle: 'High Visibility',
    color: Color(0xFFFF5A1F),
    isProOnly: true,
  ),
  cyberAmber(
    id: 'brass',
    displayName: 'Brass',
    subtitle: 'Classic Instrument',
    color: Color(0xFFC9A227),
    isProOnly: false,
  ),
  hyperViolet(
    id: 'ink',
    displayName: 'Ink',
    subtitle: 'Muted Technical Slate',
    color: Color(0xFF8FA3BF),
    isProOnly: true,
  ),
  glacierBlue(
    id: 'moss',
    displayName: 'Moss',
    subtitle: 'Calm Field Tone',
    color: Color(0xFF8DA67A),
    isProOnly: true,
  );

  const ProAccentVariant({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.color,
    required this.isProOnly,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final Color color;
  final bool isProOnly;

  AccentFinish get finish {
    switch (this) {
      case ProAccentVariant.electricEmerald:
        return AccentFinish.signal;
      case ProAccentVariant.cyberAmber:
        return AccentFinish.brass;
      case ProAccentVariant.hyperViolet:
        return AccentFinish.ink;
      case ProAccentVariant.glacierBlue:
        return AccentFinish.moss;
    }
  }

  static ProAccentVariant fromId(String? id) {
    final finish = AccentFinish.fromId(id);
    switch (finish) {
      case AccentFinish.signal:
        return ProAccentVariant.electricEmerald;
      case AccentFinish.brass:
        return ProAccentVariant.cyberAmber;
      case AccentFinish.ink:
        return ProAccentVariant.hyperViolet;
      case AccentFinish.moss:
        return ProAccentVariant.glacierBlue;
    }
  }
}
