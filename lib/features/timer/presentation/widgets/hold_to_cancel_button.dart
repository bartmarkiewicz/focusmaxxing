import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

class HoldToCancelButton extends StatefulWidget {
  const HoldToCancelButton({
    super.key,
    required this.progress,
    required this.onHoldStart,
    required this.onHoldEnd,
    this.onCancelImmediate,
  });

  final double progress;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback? onCancelImmediate;

  @override
  State<HoldToCancelButton> createState() => _HoldToCancelButtonState();
}

class _HoldToCancelButtonState extends State<HoldToCancelButton> {
  int _lastHapticTier = 0;
  DateTime? _touchStartTime;

  @override
  void didUpdateWidget(covariant HoldToCancelButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == 0.0) {
      _lastHapticTier = 0;
    } else {
      final currentTier = (widget.progress * 4).floor(); // 0: 0-25%, 1: 25-50%, 2: 50-75%, 3: 75-100%
      if (currentTier > _lastHapticTier) {
        _lastHapticTier = currentTier;
        unawaited(HapticFeedback.lightImpact());
      }
    }
  }

  @override
  void dispose() {
    if (_touchStartTime != null) {
      _touchStartTime = null;
      widget.onHoldEnd();
    }
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _touchStartTime = DateTime.now();
    unawaited(HapticFeedback.selectionClick());
    widget.onHoldStart();
  }

  void _handleTapUp(TapUpDetails _) {
    _evaluateRelease();
  }

  void _handleTapCancel() {
    _evaluateRelease();
  }

  void _evaluateRelease() {
    final startTime = _touchStartTime;
    if (startTime == null) return;
    _touchStartTime = null;

    final holdDurationMs = DateTime.now().difference(startTime).inMilliseconds;

    widget.onHoldEnd();

    // If released quickly (tap gesture without sustained hold), prompt the user
    if (holdDurationMs < 600 && widget.progress < 0.2 && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hold for 5 full seconds to cancel session'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAccessibleCancelConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Active Session?'),
        content: const Text(
          'Are you sure you want to cancel this focus block? Momentum will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('KEEP FOCUSING'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('CONFIRM CANCEL'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (widget.onCancelImmediate != null) {
        widget.onCancelImmediate!();
      } else {
        widget.onHoldStart();
        widget.onHoldEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = (widget.progress * 100).toInt();

    final errorColor = colorScheme.error;
    final isHolding = widget.progress > 0;

    return Semantics(
      button: true,
      label: 'Hold for 5 seconds to cancel session. Progress: $percent percent.',
      hint: 'Double tap to open cancellation confirmation',
      onTap: () => _showAccessibleCancelConfirmation(context),
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Cancel session'): () =>
            _showAccessibleCancelConfirmation(context),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHolding
                  ? errorColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: widget.progress.clamp(0.0, 1.0),
                  heightFactor: 1.0,
                  child: Container(
                    color: errorColor.withValues(alpha: 0.35),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: isHolding
                            ? errorColor
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHolding
                            ? 'HOLD TO CANCEL (${(5.0 * (1.0 - widget.progress)).toStringAsFixed(1)}s)'
                            : 'Hold to Cancel (5s)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isHolding
                              ? errorColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
    );
  }
}
