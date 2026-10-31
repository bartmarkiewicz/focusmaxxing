import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';

/// 5-second press-and-hold gesture button for cancelling a Maximum Focus session
/// from the Hard-Lock Overlay.
class OverlayHoldToCancelButton extends StatefulWidget {
  const OverlayHoldToCancelButton({
    super.key,
    required this.onCancelCompleted,
  });

  final Future<void> Function() onCancelCompleted;

  @override
  State<OverlayHoldToCancelButton> createState() =>
      _OverlayHoldToCancelButtonState();
}

class _OverlayHoldToCancelButtonState extends State<OverlayHoldToCancelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdCancelController;

  @override
  void initState() {
    super.initState();
    _holdCancelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _holdCancelController.reset();
          unawaited(widget.onCancelCompleted());
        }
      });
  }

  @override
  void dispose() {
    _holdCancelController.dispose();
    super.dispose();
  }

  void _onHoldStart(TapDownDetails _) {
    unawaited(HapticFeedback.lightImpact());
    _holdCancelController.forward();
  }

  void _onHoldEnd([dynamic _]) {
    if (_holdCancelController.status != AnimationStatus.completed) {
      _holdCancelController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _holdCancelController,
      builder: (context, _) {
        final progress = _holdCancelController.value;
        final percent = (progress * 100).toInt();
        final remainingHoldSeconds =
            (5 - (progress * 5)).ceil().clamp(1, 5);
        return Semantics(
          button: true,
          label:
              'Hold 5 seconds to cancel session. Progress: $percent percent.',
          customSemanticsActions: {
            const CustomSemanticsAction(label: 'Cancel session'): () =>
                unawaited(widget.onCancelCompleted()),
          },
          child: GestureDetector(
            key: const Key('overlay_hold_to_cancel_button'),
            behavior: HitTestBehavior.opaque,
            onTapDown: _onHoldStart,
            onTapUp: _onHoldEnd,
            onTapCancel: _onHoldEnd,
            child: Container(
              width: double.infinity,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF141720),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: OverlayTheme.alertColor.withValues(
                    alpha: progress > 0 ? 0.85 : 0.45,
                  ),
                  width: 1.5,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: ColoredBox(
                      color: OverlayTheme.alertColor.withValues(alpha: 0.35),
                    ),
                  ),
                  Center(
                    child: Text(
                      progress > 0
                          ? 'KEEP HOLDING ($remainingHoldSeconds S) TO CANCEL...'
                          : 'HOLD 5S TO CANCEL SESSION',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
