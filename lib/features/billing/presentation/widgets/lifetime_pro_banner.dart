import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:provider/provider.dart';

/// High-contrast Lifetime Pro banner card showcasing the one-time $9.99 unlock
/// when locked, and transitioning to the active Lifetime Pro badge when unlocked.
class LifetimeProBanner extends StatelessWidget {
  final BillingNotifier? notifier;

  const LifetimeProBanner({
    super.key,
    this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final billingNotifier = notifier ?? context.read<BillingNotifier?>();
    if (billingNotifier == null) {
      return const _LockedProBanner(notifier: null);
    }

    return ListenableBuilder(
      listenable: billingNotifier,
      builder: (context, _) {
        if (billingNotifier.isProUnlocked) {
          return _UnlockedProBanner(notifier: billingNotifier);
        }
        return _LockedProBanner(notifier: billingNotifier);
      },
    );
  }
}

class _LockedProBanner extends StatelessWidget {
  final BillingNotifier? notifier;

  const _LockedProBanner({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedPrice = notifier?.productDetails.price ?? r'$9.99';
    final isLoading = notifier?.isLoading ?? false;
    final errorMessage = notifier?.errorMessage;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentStreakGold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentStreakGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.accentStreakGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock Unlimited Shielding & Audio for $formattedPrice',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textHighContrast,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One-time flat payment · No recurring subscriptions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FeatureBulletItem(
            text: 'Unlimited app blocking (lifts the 2-app free cap)',
          ),
          const SizedBox(height: 6),
          const _FeatureBulletItem(
            text: 'Full neurodivergent audio engine (Brown noise, 40Hz, Rain)',
          ),
          const SizedBox(height: 6),
          const _FeatureBulletItem(
            text: 'Scheduled auto-shielding & offline privacy forever',
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _BillingErrorMessage(
              message: errorMessage,
              onDismiss: () => notifier?.clearError(),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('buy_lifetime_pro_button'),
              onPressed: isLoading || notifier == null
                  ? null
                  : () {
                      unawaited(notifier!.buyLifetimePro());
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentStreakGold,
                foregroundColor: AppColors.surfaceMidnight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.surfaceMidnight,
                        ),
                      ),
                    )
                  : Text(
                      'Unlock Lifetime Pro — $formattedPrice',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              key: const ValueKey('restore_purchases_button'),
              onPressed: isLoading || notifier == null
                  ? null
                  : () {
                      unawaited(notifier!.restorePurchases());
                    },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Restore Purchases',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockedProBanner extends StatelessWidget {
  final BillingNotifier? notifier;

  const _UnlockedProBanner({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = notifier?.unlockStatus.orderId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentStreakGold,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Text(
            '⭐',
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⭐ Lifetime Pro Unlocked',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.accentStreakGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LIFETIME PRO: ACTIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textHighContrast,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero subscriptions · Unlimited blocking & offline privacy',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (orderId != null && orderId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order ID: $orderId',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBulletItem extends StatelessWidget {
  final String text;

  const _FeatureBulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: AppColors.accentStreakGold,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textHighContrast,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _BillingErrorMessage({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentHardLock.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentHardLock.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.accentHardLock,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textHighContrast,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
              minHeight: kMinInteractiveDimension,
            ),
            padding: const EdgeInsets.all(8),
            color: AppColors.textMuted,
            tooltip: 'Dismiss message',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Compact supporter badge rendered in app headers when Lifetime Pro is unlocked.
class ProSupporterBadge extends StatelessWidget {
  final bool? isPro;
  final BillingNotifier? notifier;

  const ProSupporterBadge({
    super.key,
    this.isPro,
    this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    if (isPro != null) {
      return isPro! ? const _ProBadgeChip() : const SizedBox.shrink();
    }

    final billingNotifier = notifier ?? context.read<BillingNotifier?>();
    if (billingNotifier == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: billingNotifier,
      builder: (context, _) => billingNotifier.isProUnlocked
          ? const _ProBadgeChip()
          : const SizedBox.shrink(),
    );
  }
}

class _ProBadgeChip extends StatelessWidget {
  const _ProBadgeChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentStreakGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentStreakGold.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: AppColors.accentStreakGold,
          ),
          const SizedBox(width: 4),
          Text(
            'LIFETIME PRO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.accentStreakGold,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
