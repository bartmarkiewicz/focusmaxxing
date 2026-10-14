import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

class TimerDialWidget extends StatelessWidget {
  const TimerDialWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.taskGoal,
    this.isPaused = false,
    this.isRestMode = false,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String? taskGoal;
  final bool isPaused;
  final bool isRestMode;

  double get _progress {
    if (totalSeconds <= 0) return 0.0;
    final elapsed = totalSeconds - remainingSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedTime = TimeFormatter.formatMMSS(remainingSeconds);

    final accentColor = isRestMode
        ? colorScheme.secondary
        : colorScheme.primary;
    final trackColor = colorScheme.outlineVariant.withValues(alpha: 0.35);

    final trimmedGoal = taskGoal?.trim();
    final hasGoal = trimmedGoal != null && trimmedGoal.isNotEmpty;

    return Semantics(
      label: '$formattedTime remaining. ${isPaused ? "Paused." : ""}',
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dialSize = math.min(constraints.maxWidth, 280.0);
            return SizedBox(
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
                        if (isPaused)
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
                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                            fontFeatures: const [FontFeature.tabularFigures()],
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
                        ] else if (isRestMode) ...[
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
                        ],
                      ],
                    ),
                  ),
                ],
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
