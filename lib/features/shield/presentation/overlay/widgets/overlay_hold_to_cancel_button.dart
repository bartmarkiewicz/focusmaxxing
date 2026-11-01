import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';

class OverlayHoldToCancelButton extends StatelessWidget {
  const OverlayHoldToCancelButton({
    super.key,
    required this.onCancelCompleted,
  });

  final Future<void> Function() onCancelCompleted;

  @override
  Widget build(BuildContext context) {
    return HoldButton(
      key: const Key('overlay_hold_to_cancel_button'),
      label: 'Hold to end session',
      holdDuration: const Duration(seconds: 5),
      onTriggered: onCancelCompleted,
    );
  }
}
