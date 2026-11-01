import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

class ReadoutRow extends StatelessWidget {
  const ReadoutRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.showDivider = true,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: InstrumentTokens.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 15,
                height: 22 / 15,
                color: tokens.ink,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: valueColor ?? tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: InstrumentTokens.s8),
            trailing!,
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: tokens.surfaceSunken,
            child: content,
          )
        else
          content,
        if (showDivider)
          Container(
            height: 1,
            color: tokens.rule,
          ),
      ],
    );
  }
}
