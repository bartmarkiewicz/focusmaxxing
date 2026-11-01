import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

enum _InstrumentButtonVariant { primary, secondary, text }

class InstrumentButton extends StatelessWidget {
  const InstrumentButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
  }) : _variant = _InstrumentButtonVariant.primary;

  const InstrumentButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
  }) : _variant = _InstrumentButtonVariant.secondary;

  const InstrumentButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
  }) : _variant = _InstrumentButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isFullWidth;
  final _InstrumentButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isEnabled = onPressed != null;

    final labelWidget = Text(
      label,
      style: TextStyle(
        fontFamily: InstrumentTokens.fontUi,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 20 / 16,
        color: switch (_variant) {
          _InstrumentButtonVariant.primary =>
            isEnabled ? tokens.accentInk : tokens.inkFaint,
          _InstrumentButtonVariant.secondary =>
            isEnabled ? tokens.ink : tokens.inkFaint,
          _InstrumentButtonVariant.text =>
            isEnabled ? tokens.inkMuted : tokens.inkFaint,
        },
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final content = icon == null
        ? labelWidget
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon!,
              const SizedBox(width: InstrumentTokens.s8),
              Flexible(child: labelWidget),
            ],
          );

    final buttonStyle = switch (_variant) {
      _InstrumentButtonVariant.primary => FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          disabledBackgroundColor: tokens.surfaceSunken,
          foregroundColor: tokens.accentInk,
          disabledForegroundColor: tokens.inkFaint,
          elevation: 0,
          minimumSize: Size(isFullWidth ? double.infinity : 0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.s16,
            vertical: InstrumentTokens.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
        ),
      _InstrumentButtonVariant.secondary => OutlinedButton.styleFrom(
          foregroundColor: tokens.ink,
          disabledForegroundColor: tokens.inkFaint,
          side: BorderSide(
            color: isEnabled ? tokens.ruleStrong : tokens.rule,
            width: 1,
          ),
          elevation: 0,
          minimumSize: Size(isFullWidth ? double.infinity : 0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.s16,
            vertical: InstrumentTokens.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
        ),
      _InstrumentButtonVariant.text => TextButton.styleFrom(
          foregroundColor: tokens.inkMuted,
          disabledForegroundColor: tokens.inkFaint,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.s12,
            vertical: InstrumentTokens.s8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          ),
        ),
    };

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: switch (_variant) {
        _InstrumentButtonVariant.primary => FilledButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: content,
          ),
        _InstrumentButtonVariant.secondary => OutlinedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: content,
          ),
        _InstrumentButtonVariant.text => TextButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: content,
          ),
      },
    );
  }
}
