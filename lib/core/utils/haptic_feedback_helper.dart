import 'dart:async';
import 'package:flutter/services.dart';

abstract final class HapticFeedbackHelper {
  static Future<void> victoryBurst() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> lightClick() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
