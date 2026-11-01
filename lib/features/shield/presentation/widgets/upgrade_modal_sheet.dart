import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
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
    final tokens = context.tokens;

    return Sheet(
      title: _isSwapMode ? 'Swap Shielded App' : '2-App Free Cap Reached',
      child: _isSwapMode
          ? _buildSwapMode(tokens)
          : _buildPaywallMode(tokens),
    );
  }

  Widget _buildPaywallMode(InstrumentTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'The Free Tier shields up to 2 apps simultaneously. Upgrade to Pro for unlimited blocking or swap one of your 2 active apps for free.',
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 14,
            height: 20 / 14,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(height: InstrumentTokens.s16),
        ReadoutRow(
          label: 'Attempting to shield ${widget.candidateAppName}',
          value: widget.candidateAppName,
          showDivider: true,
        ),
        const ReadoutRow(
          label: 'Active apps cap',
          value: '2 apps (Free)',
          showDivider: true,
        ),
        const ReadoutRow(
          label: 'Focusmaxxing Pro',
          value: 'Unlimited',
          showDivider: false,
        ),
        const SizedBox(height: InstrumentTokens.s20),
        InstrumentButton.primary(
          key: const ValueKey('unlock_lifetime_pro_button'),
          label: 'Unlock Lifetime Pro — \$9.99',
          onPressed: widget.onUnlockPro,
        ),
        const SizedBox(height: InstrumentTokens.s12),
        InstrumentButton.secondary(
          key: const ValueKey('swap_free_app_button'),
          label: 'Swap Free App',
          onPressed: () {
            setState(() {
              _isSwapMode = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSwapMode(InstrumentTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Select which currently shielded app to replace with ${widget.candidateAppName}:',
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 14,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(height: InstrumentTokens.s16),
        RadioGroup<String>(
          groupValue: _selectedPackageToReplace,
          onChanged: (val) {
            setState(() {
              _selectedPackageToReplace = val;
            });
          },
          child: Column(
            children: [
              for (final app in widget.activeApps)
                Material(
                  color: Colors.transparent,
                  child: RadioListTile<String>(
                    key: ValueKey('swap_option_${app.packageName}'),
                    value: app.packageName,
                    title: Text(
                      app.appName,
                      style: TextStyle(
                        fontFamily: InstrumentTokens.fontUi,
                        fontSize: 15,
                        color: tokens.ink,
                      ),
                    ),
                    subtitle: Text(
                      app.packageName,
                      style: TextStyle(
                        fontFamily: InstrumentTokens.fontMono,
                        fontSize: 11,
                        color: tokens.inkMuted,
                      ),
                    ),
                    activeColor: tokens.accent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: InstrumentTokens.s16),
        InstrumentButton.primary(
          key: const ValueKey('confirm_swap_button'),
          label: 'Swap With ${widget.candidateAppName}',
          onPressed: _selectedPackageToReplace != null
              ? () => widget.onConfirmSwap(_selectedPackageToReplace!)
              : null,
        ),
        const SizedBox(height: InstrumentTokens.s8),
        InstrumentButton.text(
          label: 'Back',
          onPressed: () {
            setState(() {
              _isSwapMode = false;
            });
          },
        ),
      ],
    );
  }
}
