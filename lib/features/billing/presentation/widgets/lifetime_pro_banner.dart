import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:provider/provider.dart';

/// Clean spec sheet style Lifetime Pro banner matching "The Instrument" aesthetic.
class LifetimeProBanner extends StatelessWidget {
  const LifetimeProBanner({
    super.key,
    this.notifier,
  });

  final BillingNotifier? notifier;

  @override
  Widget build(BuildContext context) {
    final billingNotifier = notifier ?? context.read<BillingNotifier?>();
    if (billingNotifier == null) {
      return const _LockedProSpecSheet(notifier: null);
    }

    return ListenableBuilder(
      listenable: billingNotifier,
      builder: (context, _) {
        if (billingNotifier.isProUnlocked) {
          return const _UnlockedProBadge();
        }
        return _LockedProSpecSheet(notifier: billingNotifier);
      },
    );
  }
}

class _LockedProSpecSheet extends StatelessWidget {
  const _LockedProSpecSheet({required this.notifier});

  final BillingNotifier? notifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final formattedPrice = notifier?.productDetails.price ?? r'$9.99';
    final isLoading = notifier?.isLoading ?? false;
    final errorMessage = notifier?.errorMessage;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.ruleStrong, width: 1),
      ),
      padding: const EdgeInsets.all(InstrumentTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.proTitle,
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                  border: Border.all(color: tokens.accent, width: 1),
                ),
                child: Text(
                  AppStrings.proTag,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: InstrumentTokens.s16),
          const ReadoutRow(
            label: 'Physical finishes',
            value: 'Brass · Signal · Ink · Moss',
            showDivider: true,
          ),
          const ReadoutRow(
            label: 'Brainrot Shield',
            value: 'Unlimited apps',
            showDivider: true,
          ),
          const ReadoutRow(
            label: 'Automated schedules',
            value: 'Enabled',
            showDivider: true,
          ),
          const ReadoutRow(
            label: 'Ambient soundscapes',
            value: 'Full library',
            showDivider: false,
          ),
          const SizedBox(height: InstrumentTokens.s16),
          if (errorMessage != null) ...[
            Text(
              errorMessage,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 13,
                color: tokens.danger,
              ),
            ),
            const SizedBox(height: InstrumentTokens.s8),
          ],
          InstrumentButton.primary(
            key: const ValueKey('buy_lifetime_pro_button'),
            label: isLoading ? 'Contacting Store...' : AppStrings.buyOnce(formattedPrice),
            onPressed: isLoading
                ? null
                : () async {
                    unawaited(HapticFeedback.selectionClick());
                    await notifier?.buyLifetimePro();
                  },
          ),
          const SizedBox(height: InstrumentTokens.s8),
          Text(
            AppStrings.oneTimeNotice,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontUi,
              fontSize: 12,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(height: InstrumentTokens.s4),
          Center(
            child: InstrumentButton.text(
              key: const ValueKey('restore_purchases_button'),
              label: AppStrings.restorePurchases,
              onPressed: isLoading
                  ? null
                  : () async {
                      unawaited(HapticFeedback.selectionClick());
                      await notifier?.restorePurchases();
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockedProBadge extends StatelessWidget {
  const _UnlockedProBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: InstrumentTokens.gutter,
        vertical: InstrumentTokens.s16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InstrumentTokens.r1),
              border: Border.all(color: tokens.accent, width: 1),
            ),
            child: Text(
              AppStrings.proTag,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: tokens.accent,
              ),
            ),
          ),
          const SizedBox(width: InstrumentTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lifetime Pro Active',
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
                Text(
                  'All finishes and unlimited shields unlocked.',
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 12,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact PRO supporter badge displayed in the app bar when Lifetime Pro is unlocked.
class ProSupporterBadge extends StatelessWidget {
  const ProSupporterBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingNotifier?>();
    if (billing == null || !billing.isProUnlocked) {
      return const SizedBox.shrink();
    }
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.accent, width: 1),
      ),
      child: Text(
        AppStrings.proTag,
        style: TextStyle(
          fontFamily: InstrumentTokens.fontMono,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: tokens.accent,
        ),
      ),
    );
  }
}

