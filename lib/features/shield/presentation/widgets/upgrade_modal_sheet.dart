import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';

class UpgradeModalSheet extends StatefulWidget {
  const UpgradeModalSheet({
    super.key,
    required this.activeApps,
    required this.candidateAppName,
    required this.onUnlockPro,
    required this.onConfirmSwap,
  });

  final List<ShieldedAppEntity> activeApps;
  final String candidateAppName;
  final VoidCallback onUnlockPro;
  final ValueChanged<String> onConfirmSwap;

  @override
  State<UpgradeModalSheet> createState() => _UpgradeModalSheetState();
}

class _UpgradeModalSheetState extends State<UpgradeModalSheet> {
  bool _isSwapMode = false;
  String? _selectedPackageToReplace;

  @override
  void initState() {
    super.initState();
    if (widget.activeApps.isNotEmpty) {
      _selectedPackageToReplace = widget.activeApps.first.packageName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceHairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isSwapMode)
              _PaywallContent(
                candidateAppName: widget.candidateAppName,
                onUnlockPro: widget.onUnlockPro,
                onOpenSwapMode: () {
                  setState(() {
                    _isSwapMode = true;
                  });
                },
              )
            else
              _SwapContent(
                activeApps: widget.activeApps,
                candidateAppName: widget.candidateAppName,
                selectedPackageToReplace: _selectedPackageToReplace,
                onSelectPackage: (pkg) {
                  setState(() {
                    _selectedPackageToReplace = pkg;
                  });
                },
                onBack: () {
                  setState(() {
                    _isSwapMode = false;
                  });
                },
                onConfirmSwap: widget.onConfirmSwap,
              ),
          ],
        ),
      ),
    );
  }
}

class _PaywallContent extends StatelessWidget {
  const _PaywallContent({
    required this.candidateAppName,
    required this.onUnlockPro,
    required this.onOpenSwapMode,
  });

  final String candidateAppName;
  final VoidCallback onUnlockPro;
  final VoidCallback onOpenSwapMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentStreakGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.accentStreakGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2-App Free Cap Reached',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textHighContrast,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Attempting to shield $candidateAppName',
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
        Text(
          'The Free Tier shields up to 2 apps simultaneously. Unlock Lifetime Pro for unlimited app blocking with a single one-time payment — or swap one of your active apps right now for free.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('unlock_lifetime_pro_button'),
            onPressed: onUnlockPro,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentStreakGold,
              foregroundColor: AppColors.surfaceMidnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Unlock Lifetime Pro — \$9.99',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            key: const ValueKey('swap_free_app_button'),
            onPressed: onOpenSwapMode,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textHighContrast,
              side: const BorderSide(color: AppColors.surfaceHairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Swap Free App',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwapContent extends StatelessWidget {
  const _SwapContent({
    required this.activeApps,
    required this.candidateAppName,
    required this.selectedPackageToReplace,
    required this.onSelectPackage,
    required this.onBack,
    required this.onConfirmSwap,
  });

  final List<ShieldedAppEntity> activeApps;
  final String candidateAppName;
  final String? selectedPackageToReplace;
  final ValueChanged<String> onSelectPackage;
  final VoidCallback onBack;
  final ValueChanged<String> onConfirmSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPkg = selectedPackageToReplace;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Swap With $candidateAppName',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textHighContrast,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select which currently shielded app to uncheck and replace:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: selectedPkg,
          onChanged: (value) {
            if (value != null) {
              onSelectPackage(value);
            }
          },
          child: Column(
            children: [
              for (final app in activeApps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selectedPkg == app.packageName
                        ? AppColors.surfaceElevated
                        : AppColors.surfaceMidnight,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('swap_option_${app.packageName}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelectPackage(app.packageName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedPkg == app.packageName
                                ? AppColors.accentLockIn
                                : AppColors.surfaceHairline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: app.packageName,
                              activeColor: AppColors.accentLockIn,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.appName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textHighContrast,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    app.packageName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.surfaceHairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('confirm_swap_button'),
                  onPressed: selectedPkg == null
                      ? null
                      : () => onConfirmSwap(selectedPkg),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentLockIn,
                    foregroundColor: AppColors.surfaceMidnight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Swap',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
