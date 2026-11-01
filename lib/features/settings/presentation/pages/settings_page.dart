import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/accent_finish.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final themeNotifier = context.watch<ThemeNotifier?>();
    final billingNotifier = context.watch<BillingNotifier?>();
    final isPro = billingNotifier?.isProUnlocked ?? false;
    final currentThemeMode = themeNotifier?.themeMode ?? ThemeMode.system;
    final currentFinish = themeNotifier?.currentFinish ?? AccentFinish.brass;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        title: Text(
          AppStrings.settingsTitle,
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_outlined, color: tokens.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.gutter,
            vertical: InstrumentTokens.s12,
          ),
          children: [
            const SectionHeader(title: AppStrings.appearanceSection),
            const SizedBox(height: InstrumentTokens.s12),
            Row(
              children: [
                Expanded(
                  child: Tag(
                    label: AppStrings.themeSystem,
                    isSelected: currentThemeMode == ThemeMode.system,
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      if (themeNotifier != null) {
                        unawaited(themeNotifier.setThemeMode(ThemeMode.system));
                      }
                    },
                  ),
                ),
                const SizedBox(width: InstrumentTokens.s8),
                Expanded(
                  child: Tag(
                    label: AppStrings.themeDark,
                    isSelected: currentThemeMode == ThemeMode.dark,
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      if (themeNotifier != null) {
                        unawaited(themeNotifier.setThemeMode(ThemeMode.dark));
                      }
                    },
                  ),
                ),
                const SizedBox(width: InstrumentTokens.s8),
                Expanded(
                  child: Tag(
                    label: AppStrings.themeLight,
                    isSelected: currentThemeMode == ThemeMode.light,
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      if (themeNotifier != null) {
                        unawaited(themeNotifier.setThemeMode(ThemeMode.light));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: InstrumentTokens.s24),
            const SectionHeader(title: AppStrings.finishSection),
            const SizedBox(height: InstrumentTokens.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AccentFinish.values.map((finish) {
                final isSelected = currentFinish == finish;
                final isLocked = finish.isProOnly && !isPro;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (isLocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${finish.displayName} finish requires Pro unlock.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    unawaited(HapticFeedback.selectionClick());
                    if (themeNotifier != null) {
                      await themeNotifier.setFinish(finish, isLifetimePro: isPro);
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: finish.darkTokens.accent,
                          border: Border.all(
                            color: isSelected ? tokens.ink : tokens.ruleStrong,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                        child: isLocked
                            ? const Center(
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: Color(0xFF121110),
                                ),
                              )
                            : (isSelected
                                ? Center(
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: finish.darkTokens.accentInk,
                                    ),
                                  )
                                : null),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        finish.displayName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontMono,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          letterSpacing: 0.6,
                          color: isSelected ? tokens.ink : tokens.inkMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: InstrumentTokens.s24),
            const SectionHeader(title: 'DAILY REMINDER'),
            Consumer<InsightsNotifier?>(
              builder: (context, insightsNotifier, _) {
                if (insightsNotifier == null) return const SizedBox.shrink();
                final enabled = insightsNotifier.isDailyReminderEnabled;
                final time = insightsNotifier.dailyReminderTime;

                return Column(
                  children: [
                    ReadoutRow(
                      label: 'Daily notification',
                      value: enabled
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : 'Off',
                      onTap: () async {
                        unawaited(HapticFeedback.selectionClick());
                        if (!enabled) {
                          await insightsNotifier.setDailyReminderEnabled(true);
                        } else {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: insightsNotifier.dailyReminderHour,
                              minute: insightsNotifier.dailyReminderMinute,
                            ),
                          );
                          if (selected != null) {
                            await insightsNotifier.setDailyReminderTime(
                              selected.hour,
                              selected.minute,
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: InstrumentTokens.s24),
            const SectionHeader(title: AppStrings.proSection),
            const SizedBox(height: InstrumentTokens.s12),
            LifetimeProBanner(notifier: billingNotifier),
            const SizedBox(height: InstrumentTokens.s24),
            const ReadoutRow(
              label: 'Version',
              value: '1.0.0 (Instrument)',
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}
