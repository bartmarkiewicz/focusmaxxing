import 'package:flutter/material.dart';

abstract final class ColorUtils {
  static Color fromHex(
    String hex, {
    Color defaultColor = const Color(0xFF00E5FF),
  }) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (clean.length == 8) {
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return defaultColor;
  }
}
