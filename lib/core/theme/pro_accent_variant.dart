import 'package:flutter/material.dart';

enum ProAccentVariant {
  electricEmerald(
    id: 'electric_emerald',
    displayName: 'Electric Emerald',
    subtitle: 'Default Focus',
    color: Color(0xFF00E676),
    isProOnly: false,
  ),
  cyberAmber(
    id: 'cyber_amber',
    displayName: 'Cyber Amber',
    subtitle: 'High Intensity',
    color: Color(0xFFFFAB00),
    isProOnly: true,
  ),
  hyperViolet(
    id: 'hyper_violet',
    displayName: 'Hyper Violet',
    subtitle: 'Deep Meditative Flow',
    color: Color(0xFFB388FF),
    isProOnly: true,
  ),
  glacierBlue(
    id: 'glacier_blue',
    displayName: 'Glacier Blue',
    subtitle: 'Rest Mode Standard',
    color: Color(0xFF38B6FF),
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

  static ProAccentVariant fromId(String? id) {
    if (id == null) return ProAccentVariant.electricEmerald;
    for (final variant in ProAccentVariant.values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return ProAccentVariant.electricEmerald;
  }
}
