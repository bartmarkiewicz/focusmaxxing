import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData buildDarkTheme(ColorScheme? dynamicColorScheme) {
    final baseColorScheme = dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: AppColors.accentLockIn,
          brightness: Brightness.dark,
        );

    final colorScheme = baseColorScheme.copyWith(
      surface: AppColors.surfaceMidnight,
      surfaceContainerHighest: AppColors.surfaceRaised,
      primary: AppColors.accentLockIn,
      secondary: AppColors.accentRestMode,
      tertiary: AppColors.accentStreakGold,
      error: AppColors.accentHardLock,
      outline: AppColors.surfaceHairline,
      outlineVariant: AppColors.surfaceHairline,
      onSurface: AppColors.textHighContrast,
      onSurfaceVariant: AppColors.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surfaceMidnight,
      colorScheme: colorScheme,
      cardTheme: const CardThemeData(
        color: AppColors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.surfaceHairline, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.surfaceHairline, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceMidnight,
        indicatorColor: AppColors.accentLockIn.withValues(alpha: 0.2),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentLockIn, width: 1.5),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textHighContrast,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.5,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineMedium: TextStyle(
          color: AppColors.textHighContrast,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textHighContrast,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
