import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final backgroundColor = isSelected ? tokens.ink : Colors.transparent;
    final textColor = isSelected ? tokens.bg : tokens.ink;
    final borderColor = isSelected ? tokens.ink : tokens.ruleStrong;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InstrumentTokens.r1),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InstrumentTokens.s8,
              vertical: InstrumentTokens.s6,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(InstrumentTokens.r1),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: InstrumentTokens.s4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontMono,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
