import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/accent_finish.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

abstract final class AppTheme {
  static ThemeData buildDarkTheme(
    ColorScheme? dynamicColorScheme, {
    Color? accentColor,
    AccentFinish finish = AccentFinish.brass,
  }) {
    final effectiveFinish = (accentColor != null)
        ? AccentFinish.fromId(null)
        : finish;
    final baseTokens = effectiveFinish.tokensFor(Brightness.dark);
    final tokens = (accentColor != null)
        ? baseTokens.copyWith(accent: accentColor)
        : baseTokens;

    return _buildTheme(Brightness.dark, tokens);
  }

  static ThemeData buildLightTheme(
    ColorScheme? dynamicColorScheme, {
    Color? accentColor,
    AccentFinish finish = AccentFinish.brass,
  }) {
    final effectiveFinish = (accentColor != null)
        ? AccentFinish.fromId(null)
        : finish;
    final baseTokens = effectiveFinish.tokensFor(Brightness.light);
    final tokens = (accentColor != null)
        ? baseTokens.copyWith(accent: accentColor)
        : baseTokens;

    return _buildTheme(Brightness.light, tokens);
  }

  static ThemeData _buildTheme(Brightness brightness, InstrumentTokens tokens) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentInk,
      secondary: tokens.inkMuted,
      onSecondary: tokens.bg,
      error: tokens.danger,
      onError: isDark ? const Color(0xFF121110) : const Color(0xFFFFFFFF),
      surface: tokens.surface,
      onSurface: tokens.ink,
      onSurfaceVariant: tokens.inkMuted,
      outline: tokens.rule,
      outlineVariant: tokens.ruleStrong,
      surfaceContainerHighest: tokens.surfaceSunken,
    );

    final textTheme = TextTheme(
      // displayLarge: JetBrains Mono 72 / 72 / 300
      displayLarge: TextStyle(
        fontFamily: InstrumentTokens.fontMono,
        fontSize: 72,
        height: 1.0,
        fontWeight: FontWeight.w300,
        color: tokens.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // headlineMedium: Inter Tight 24 / 30 / 600
      headlineMedium: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 24,
        height: 30 / 24,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
      // titleMedium: Inter Tight 17 / 24 / 600
      titleMedium: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
      // bodyLarge: Inter Tight 15 / 22 / 400
      bodyLarge: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: tokens.ink,
      ),
      // bodyMedium: Inter Tight 15 / 22 / 400 inkMuted
      bodyMedium: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: tokens.inkMuted,
      ),
      // labelSmall: JetBrains Mono 11 / 14 / 500, +0.6 tracking, UPPERCASE
      labelSmall: TextStyle(
        fontFamily: InstrumentTokens.fontMono,
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: tokens.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // labelLarge: Inter Tight 16 / 20 / 600 (button)
      labelLarge: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 16,
        height: 20 / 16,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: InstrumentTokens.fontUi,
      extensions: <ThemeExtension<dynamic>>[tokens],
      dividerTheme: DividerThemeData(
        color: tokens.rule,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          side: BorderSide(color: tokens.rule),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(InstrumentTokens.r3),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          side: BorderSide(color: tokens.rule),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.bg,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? tokens.ink : tokens.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? tokens.ink : tokens.inkMuted,
            size: 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
          textStyle: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.accentInk,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: tokens.ruleStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
          textStyle: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.inkMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
          textStyle: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: tokens.inkMuted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: TextStyle(
          fontFamily: InstrumentTokens.fontUi,
          fontSize: 15,
          color: tokens.inkMuted,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: tokens.ruleStrong, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: tokens.ruleStrong, width: 1),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.rule,
      ),
    );
  }
}
