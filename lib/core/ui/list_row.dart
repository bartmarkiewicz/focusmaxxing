import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: InstrumentTokens.s4,
        vertical: InstrumentTokens.s8,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(
              width: 32,
              height: 32,
              child: Center(child: leading!),
            ),
            const SizedBox(width: InstrumentTokens.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: tokens.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 13,
                      color: tokens.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
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
