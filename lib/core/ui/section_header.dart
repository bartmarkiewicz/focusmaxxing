import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: InstrumentTokens.s24,
      bottom: InstrumentTokens.s8,
    ),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: tokens.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: InstrumentTokens.s8),
          Container(
            height: 1,
            color: tokens.rule,
          ),
        ],
      ),
    );
  }
}
