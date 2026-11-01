import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:provider/provider.dart';

/// Finish / Accent selector section matching "The Instrument" aesthetic.
class ProAccentColorSection extends StatelessWidget {
  final ThemeNotifier? themeNotifier;
  final BillingNotifier? billingNotifier;
  final bool? isProUnlocked;

  const ProAccentColorSection({
    super.key,
    this.themeNotifier,
    this.billingNotifier,
    this.isProUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeThemeNotifier = themeNotifier ?? context.read<ThemeNotifier?>();
    final activeBillingNotifier =
        billingNotifier ?? context.watch<BillingNotifier?>();

    final proUnlocked =
        isProUnlocked ?? activeBillingNotifier?.isProUnlocked ?? false;

    Widget buildSection(ProAccentVariant currentAccent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: InstrumentTokens.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'FOCUS ACCENT FINISH'),
            const SizedBox(height: InstrumentTokens.s8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InstrumentTokens.gutter,
                vertical: InstrumentTokens.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus Accent Color',
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currentAccent.displayName} · ${currentAccent.subtitle}',
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 13,
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: InstrumentTokens.s8),
            for (final variant in ProAccentVariant.values)
              _AccentVariantOptionTile(
                key: ValueKey('accent_variant_${variant.id}'),
                variant: variant,
                isSelected: currentAccent == variant,
                isProUnlocked: proUnlocked,
                onTap: () async {
                  unawaited(HapticFeedback.selectionClick());
                  if (variant.isProOnly && !proUnlocked) {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(InstrumentTokens.gutter),
                          child: LifetimeProBanner(
                            notifier: activeBillingNotifier,
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  if (activeThemeNotifier != null) {
                    await activeThemeNotifier.setAccent(
                      variant,
                      isLifetimePro: proUnlocked,
                    );
                  }
                },
              ),
          ],
        ),
      );
    }

    if (activeThemeNotifier != null) {
      return ListenableBuilder(
        listenable: activeThemeNotifier,
        builder: (context, _) =>
            buildSection(activeThemeNotifier.currentAccent),
      );
    }

    return buildSection(ProAccentVariant.electricEmerald);
  }
}

class _AccentVariantOptionTile extends StatelessWidget {
  final ProAccentVariant variant;
  final bool isSelected;
  final bool isProUnlocked;
  final VoidCallback onTap;

  const _AccentVariantOptionTile({
    super.key,
    required this.variant,
    required this.isSelected,
    required this.isProUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final showProBadge = variant.isProOnly && !isProUnlocked;

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: InstrumentTokens.rowHeight,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InstrumentTokens.gutter,
              vertical: InstrumentTokens.s8,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.rule, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: variant.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? tokens.ink : tokens.ruleStrong,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: variant.color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: InstrumentTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        variant.displayName,
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? tokens.ink : tokens.ink,
                        ),
                      ),
                      Text(
                        variant.subtitle,
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 12,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showProBadge) ...[
                  const SizedBox(width: InstrumentTokens.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                      border: Border.all(
                        color: tokens.accent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppStrings.proTag,
                      style: TextStyle(
                        fontFamily: InstrumentTokens.fontMono,
                        color: tokens.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
