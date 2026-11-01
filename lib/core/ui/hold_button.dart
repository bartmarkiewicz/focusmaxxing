import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

/// Unified hold-to-action button with physical instrument feedback.
/// Supports both self-contained timers and external progress notifiers.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    this.label = 'Hold to stop',
    this.holdDuration = const Duration(seconds: 5),
    this.onTriggered,
    this.onHoldStart,
    this.onHoldEnd,
    this.onCancelImmediate,
    this.progress = 0.0,
    this.progressListenable,
    this.isFullWidth = true,
  });

  final String label;
  final Duration holdDuration;
  final VoidCallback? onTriggered;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final VoidCallback? onCancelImmediate;
  final double progress;
  final ValueListenable<double>? progressListenable;
  final bool isFullWidth;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _internalController;
  int _lastHapticTier = 0;
  DateTime? _touchStartTime;

  bool get _isSelfManaged =>
      widget.progressListenable == null && widget.onHoldStart == null;

  double get _currentProgress {
    if (_isSelfManaged) {
      return _internalController?.value ?? 0.0;
    }
    return widget.progressListenable?.value ?? widget.progress;
  }

  @override
  void initState() {
    super.initState();
    if (_isSelfManaged) {
      _internalController = AnimationController(
        vsync: this,
        duration: widget.holdDuration,
      );
      _internalController!.addListener(_handleTick);
      _internalController!.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          unawaited(HapticFeedback.heavyImpact());
          widget.onTriggered?.call();
          _internalController?.reset();
        }
      });
    } else {
      widget.progressListenable?.addListener(_handleExternalProgressChanged);
    }
  }

  @override
  void didUpdateWidget(covariant HoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressListenable != widget.progressListenable) {
      oldWidget.progressListenable
          ?.removeListener(_handleExternalProgressChanged);
      widget.progressListenable?.addListener(_handleExternalProgressChanged);
    }
    if (widget.progressListenable == null) {
      _checkHapticTier(widget.progress);
    }
  }

  void _handleExternalProgressChanged() {
    if (!mounted) return;
    _checkHapticTier(_currentProgress);
    setState(() {});
  }

  void _checkHapticTier(double progress) {
    if (progress <= 0.0) {
      _lastHapticTier = 0;
    } else {
      final tier = (progress * 4).floor(); // 0: 0-25%, 1: 25-50%, 2: 50-75%, 3: 75-100%
      if (tier > _lastHapticTier) {
        _lastHapticTier = tier;
        unawaited(HapticFeedback.lightImpact());
      }
    }
  }

  void _handleTick() {
    if (!mounted) return;
    _checkHapticTier(_currentProgress);
    setState(() {});
  }

  @override
  void dispose() {
    widget.progressListenable?.removeListener(_handleExternalProgressChanged);
    _internalController?.dispose();
    _touchStartTime = null;
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _touchStartTime = DateTime.now();
    unawaited(HapticFeedback.selectionClick());

    if (_isSelfManaged) {
      _internalController?.forward();
    } else {
      widget.onHoldStart?.call();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _evaluateRelease();
  }

  void _handleTapCancel() {
    _evaluateRelease();
  }

  void _evaluateRelease() {
    final startTime = _touchStartTime;
    _touchStartTime = null;

    final holdDurationMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : 0;

    if (_isSelfManaged) {
      if (_internalController?.status != AnimationStatus.completed) {
        _internalController?.reverse();
      }
    } else {
      widget.onHoldEnd?.call();
    }

    // If released quickly (tap gesture without sustained hold), prompt the user
    if (holdDurationMs < 600 && _currentProgress < 0.2 && mounted) {
      final maxSec = math.max(1, widget.holdDuration.inSeconds);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hold for $maxSec full seconds to stop session'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleSemanticAction() {
    unawaited(HapticFeedback.heavyImpact());
    if (widget.onCancelImmediate != null) {
      widget.onCancelImmediate!();
    } else {
      widget.onTriggered?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = _currentProgress.clamp(0.0, 1.0);
    final isHolding = progress > 0.0;
    final maxSec = math.max(1, widget.holdDuration.inSeconds);
    final remainingSeconds = (maxSec * (1.0 - progress)).clamp(0.0, maxSec.toDouble());

    final displayText = isHolding
        ? 'HOLD ${remainingSeconds.toStringAsFixed(1)}s'
        : widget.label;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: widget.label,
      hint: 'Double tap to activate or hold for $maxSec seconds to confirm',
      onTap: _handleSemanticAction,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          height: 48,
          width: widget.isFullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(InstrumentTokens.r1),
            border: Border.all(
              color: isHolding ? tokens.danger : tokens.ruleStrong,
              width: isHolding ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(InstrumentTokens.r1),
            child: Stack(
              children: [
                // Live danger progress fill charging across the button
                if (isHolding)
                  FractionallySizedBox(
                    widthFactor: progress,
                    heightFactor: 1.0,
                    child: Container(
                      color: tokens.danger.withValues(alpha: 0.20),
                    ),
                  ),
                // Precision top highlight hairline
                if (isHolding)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 2,
                          color: tokens.danger,
                        ),
                      ),
                    ),
                  ),
                // Center icon and label
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHolding
                            ? Icons.warning_amber_rounded
                            : Icons.stop_rounded,
                        size: 18,
                        color: isHolding ? tokens.danger : tokens.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayText,
                        style: TextStyle(
                          fontFamily: isHolding
                              ? InstrumentTokens.fontMono
                              : InstrumentTokens.fontUi,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isHolding ? tokens.danger : tokens.ink,
                          letterSpacing: isHolding ? 0.6 : 0,
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
