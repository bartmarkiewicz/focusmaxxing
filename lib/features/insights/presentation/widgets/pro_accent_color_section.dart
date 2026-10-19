import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:provider/provider.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeThemeNotifier = themeNotifier ?? context.read<ThemeNotifier?>();
    final activeBillingNotifier =
        billingNotifier ?? context.watch<BillingNotifier?>();

    final proUnlocked =
        isProUnlocked ?? activeBillingNotifier?.isProUnlocked ?? false;

    Widget buildSection(ProAccentVariant currentAccent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: colorScheme.onSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Accent Color',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentAccent.displayName} · ${currentAccent.subtitle}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final variant in ProAccentVariant.values)
              _AccentVariantOptionTile(
                key: ValueKey('accent_variant_${variant.id}'),
                variant: variant,
                isSelected: currentAccent == variant,
                isProUnlocked: proUnlocked,
                onTap: () async {
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
                          padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showProBadge = variant.isProOnly && !isProUnlocked;

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: variant.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? Colors.white : AppColors.surfaceHairline,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: variant.color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        variant.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      Text(
                        variant.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showProBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentStreakGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            AppColors.accentStreakGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'PRO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.accentStreakGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
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
