import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

/// Quick-capture button shown during an active focus session for dumping stray thoughts.
class InSessionQuickCapturePill extends StatelessWidget {
  const InSessionQuickCapturePill({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: 'Dump stray thought to Backlog',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('in_session_quick_capture_pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(InstrumentTokens.r1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(InstrumentTokens.r1),
              border: Border.all(color: tokens.rule, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 16,
                  color: tokens.inkMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '+ Dump stray thought...',
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tokens.inkMuted,
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
