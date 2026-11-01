import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

class InstrumentDial extends StatefulWidget {
  const InstrumentDial({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.taskGoal,
    this.isPaused = false,
    this.isRestMode = false,
    this.onDurationChanged,
    this.size = 280.0,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String? taskGoal;
  final bool isPaused;
  final bool isRestMode;
  final ValueChanged<int>? onDurationChanged;
  final double size;

  @override
  State<InstrumentDial> createState() => _InstrumentDialState();
}

class _InstrumentDialState extends State<InstrumentDial> {
  int? _lastSnappedMinutes;

  double get _progress {
    if (widget.totalSeconds <= 0) return 0.0;
    if (widget.onDurationChanged != null) {
      final dialMaxSeconds =
          widget.totalSeconds > 3600 ? widget.totalSeconds.toDouble() : 3600.0;
      return (widget.totalSeconds / dialMaxSeconds).clamp(0.0, 1.0);
    }
    // During running session: progress represents fraction remaining (countdown sweep)
    return (widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0);
  }

  void _handleDialGesture(Offset localPosition, double dialSize) {
    if (widget.onDurationChanged == null) return;

    final center = Offset(dialSize / 2, dialSize / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < dialSize * 0.22) return;

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
    final tokens = context.tokens;
    final formattedTime = TimeFormatter.formatMMSS(widget.remainingSeconds);
    final isInteractive = widget.onDurationChanged != null;
    final trimmedGoal = widget.taskGoal?.trim();
    final hasGoal = trimmedGoal != null && trimmedGoal.isNotEmpty;
    final dialSize = widget.size;

    final formattedIncreased = TimeFormatter.formatMMSS((widget.totalSeconds + 300).clamp(300, 3600));
    final formattedDecreased = TimeFormatter.formatMMSS((widget.totalSeconds - 300).clamp(300, 3600));

    final accentColor = widget.isRestMode ? tokens.inkMuted : tokens.accent;

    return Semantics(
      slider: isInteractive,
      label: 'Timer readout: $formattedTime',
      value: formattedTime,
      increasedValue: isInteractive ? formattedIncreased : null,
      decreasedValue: isInteractive ? formattedDecreased : null,
      onIncrease: isInteractive
          ? () {
              final newSec = (widget.totalSeconds + 300).clamp(300, 3600);
              unawaited(HapticFeedback.selectionClick());
              widget.onDurationChanged!(newSec);
            }
          : null,
      onDecrease: isInteractive
          ? () {
              final newSec = (widget.totalSeconds - 300).clamp(300, 3600);
              unawaited(HapticFeedback.selectionClick());
              widget.onDurationChanged!(newSec);
            }
          : null,
      child: Center(
        child: GestureDetector(
          behavior: isInteractive
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onPanStart: isInteractive
              ? (d) => _handleDialGesture(d.localPosition, dialSize)
              : null,
          onPanUpdate: isInteractive
              ? (d) => _handleDialGesture(d.localPosition, dialSize)
              : null,
          onPanEnd: isInteractive ? (_) => _lastSnappedMinutes = null : null,
          child: SizedBox(
            width: dialSize,
            height: dialSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Static dial face (sunken background, 60 ticks, numerals)
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: _DialFacePainter(
                      faceColor: tokens.surfaceSunken,
                      ruleColor: tokens.rule,
                      ruleStrongColor: tokens.ruleStrong,
                      numeralColor: tokens.inkFaint,
                    ),
                  ),
                ),
                // Dynamic arc & needle
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: _DialArcPainter(
                      progress: _progress,
                      accentColor: accentColor,
                    ),
                  ),
                ),
                // Center Readout
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (dialSize * 0.12).clamp(16.0, 36.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isPaused)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: InstrumentTokens.s8,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: InstrumentTokens.s4),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                            border: Border.all(color: tokens.ruleStrong, width: 1),
                          ),
                          child: Text(
                            'PAUSED',
                            style: TextStyle(
                              fontFamily: InstrumentTokens.fontMono,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formattedTime,
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontMono,
                            fontSize: 72,
                            height: 1.0,
                            fontWeight: FontWeight.w300,
                            color: tokens.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: InstrumentTokens.s8),
                      if (hasGoal)
                        Text(
                          trimmedGoal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontUi,
                            fontSize: 15,
                            height: 22 / 15,
                            color: tokens.inkMuted,
                          ),
                        )
                      else if (widget.isRestMode)
                        Text(
                          'Break',
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontUi,
                            fontSize: 15,
                            color: tokens.inkMuted,
                          ),
                        )
                      else if (isInteractive)
                        Text(
                          'ROTATE TO SET TIME',
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontMono,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            color: tokens.inkMuted,
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

class _DialFacePainter extends CustomPainter {
  const _DialFacePainter({
    required this.faceColor,
    required this.ruleColor,
    required this.ruleStrongColor,
    required this.numeralColor,
  });

  final Color faceColor;
  final Color ruleColor;
  final Color ruleStrongColor;
  final Color numeralColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;

    // Sunken face background
    final facePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, facePaint);

    // Outer baseline rule
    final rimPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, outerRadius, rimPaint);

    // 60 Hairline ticks
    final tickPaint = Paint()
      ..color = ruleStrongColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const totalTicks = 60;
    for (int i = 0; i < totalTicks; i++) {
      final angle = (i * 2 * math.pi / totalTicks) - (math.pi / 2);
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;

      final startX = center.dx + (outerRadius - tickLength) * math.cos(angle);
      final startY = center.dy + (outerRadius - tickLength) * math.sin(angle);
      final endX = center.dx + outerRadius * math.cos(angle);
      final endY = center.dy + outerRadius * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      // Draw numeral for major ticks
      if (isMajor && outerRadius > 65) {
        final numeralString = i.toString();
        final textPainter = TextPainter(
          text: TextSpan(
            text: numeralString,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: outerRadius < 90 ? 8.5 : 10,
              fontWeight: FontWeight.w400,
              color: numeralColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textRadius =
            outerRadius - tickLength - (outerRadius < 90 ? 7.0 : 10.0);
        final textX =
            center.dx + textRadius * math.cos(angle) - (textPainter.width / 2);
        final textY =
            center.dy + textRadius * math.sin(angle) - (textPainter.height / 2);
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DialFacePainter oldDelegate) {
    return oldDelegate.faceColor != faceColor ||
        oldDelegate.ruleColor != ruleColor ||
        oldDelegate.ruleStrongColor != ruleStrongColor ||
        oldDelegate.numeralColor != numeralColor;
  }
}

class _DialArcPainter extends CustomPainter {
  const _DialArcPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // 3dp accent arc with butt caps
    final arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 3.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 2dp needle at the tip
    final tipAngle = startAngle + sweepAngle;
    final needleInnerRadius = radius - 14.0;
    final needleStartX = center.dx + needleInnerRadius * math.cos(tipAngle);
    final needleStartY = center.dy + needleInnerRadius * math.sin(tipAngle);
    final needleEndX = center.dx + (radius + 2) * math.cos(tipAngle);
    final needleEndY = center.dy + (radius + 2) * math.sin(tipAngle);

    final needlePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(needleStartX, needleStartY),
      Offset(needleEndX, needleEndY),
      needlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}
