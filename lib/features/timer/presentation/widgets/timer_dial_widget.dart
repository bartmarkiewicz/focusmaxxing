import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

class TimerDialWidget extends StatefulWidget {
  const TimerDialWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.taskGoal,
    this.isPaused = false,
    this.isRestMode = false,
    this.onDurationChanged,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String? taskGoal;
  final bool isPaused;
  final bool isRestMode;
  final ValueChanged<int>? onDurationChanged;

  @override
  State<TimerDialWidget> createState() => _TimerDialWidgetState();
}

class _TimerDialWidgetState extends State<TimerDialWidget> {
  int? _lastSnappedMinutes;

  double get _progress {
    if (widget.totalSeconds <= 0) return 0.0;
    if (widget.onDurationChanged != null) {
      final dialMaxSeconds =
          widget.totalSeconds > 3600 ? widget.totalSeconds.toDouble() : 3600.0;
      return (widget.totalSeconds / dialMaxSeconds).clamp(0.0, 1.0);
    }
    final elapsed = widget.totalSeconds - widget.remainingSeconds;
    return (elapsed / widget.totalSeconds).clamp(0.0, 1.0);
  }

  void _handleDialGesture(Offset localPosition, double dialSize) {
    if (widget.onDurationChanged == null) return;

    final center = Offset(dialSize / 2, dialSize / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Only scrub if touch is on the outer ring area
    if (distance < dialSize * 0.25) return;

    var angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) angle += 2 * math.pi;

    final fraction = angle / (2 * math.pi);
    final rawMinutes = (fraction * 60).round();
    const step = 5;
    var snappedMinutes = ((rawMinutes + 2) ~/ step) * step;
    if (snappedMinutes <= 0) snappedMinutes = 60;
    snappedMinutes = snappedMinutes.clamp(5, 60);

    if (snappedMinutes != _lastSnappedMinutes) {
      _lastSnappedMinutes = snappedMinutes;
      try {
        unawaited(HapticFeedback.selectionClick());
      } catch (_) {}
      widget.onDurationChanged!(snappedMinutes * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedTime = TimeFormatter.formatMMSS(widget.remainingSeconds);

    final accentColor =
        widget.isRestMode ? colorScheme.secondary : colorScheme.primary;
    final trackColor = colorScheme.outlineVariant.withValues(alpha: 0.35);

    final trimmedGoal = widget.taskGoal?.trim();
    final hasGoal = trimmedGoal != null && trimmedGoal.isNotEmpty;
    final isInteractive = widget.onDurationChanged != null;

    return Semantics(
      label: '$formattedTime remaining. ${widget.isPaused ? "Paused." : ""}',
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dialSize = math.min(constraints.maxWidth, 280.0);
            return GestureDetector(
              behavior: isInteractive
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onPanStart: isInteractive
                  ? (d) => _handleDialGesture(d.localPosition, dialSize)
                  : null,
              onPanUpdate: isInteractive
                  ? (d) => _handleDialGesture(d.localPosition, dialSize)
                  : null,
              onPanEnd:
                  isInteractive ? (_) => _lastSnappedMinutes = null : null,
              child: SizedBox(
                width: dialSize,
                height: dialSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(dialSize, dialSize),
                        painter: _DialPainter(
                          progress: _progress,
                          accentColor: accentColor,
                          trackColor: trackColor,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isPaused)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'PAUSED',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          Text(
                            formattedTime,
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (hasGoal) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"$trimmedGoal"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ] else if (widget.isRestMode) ...[
                            const SizedBox(height: 6),
                            Text(
                              'RECHARGE YOUR BRAIN',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ] else if (isInteractive) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ROTATE TO SET TIME',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0.0) {
      final arcPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    final tipAngle = startAngle + sweepAngle;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);
    final tipCenter = Offset(tipX, tipY);

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(tipCenter, 7.0, glowPaint);

    final dotPaint = Paint()..color = accentColor;
    canvas.drawCircle(tipCenter, 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor;
  }
}
