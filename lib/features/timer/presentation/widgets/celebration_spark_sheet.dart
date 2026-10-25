import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/utils/haptic_feedback_helper.dart';

@immutable
class CelebrationResult {
  final bool rollIntoNext;

  const CelebrationResult({this.rollIntoNext = false});
}

class CelebrationSparkSheet extends StatefulWidget {
  const CelebrationSparkSheet({
    super.key,
    required this.durationMinutes,
    required this.taskGoal,
  });

  final int durationMinutes;
  final String taskGoal;

  static Future<CelebrationResult?> show(
    BuildContext context, {
    required int durationMinutes,
    required String taskGoal,
  }) {
    return showModalBottomSheet<CelebrationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CelebrationSparkSheet(
        durationMinutes: durationMinutes,
        taskGoal: taskGoal,
      ),
    );
  }

  @override
  State<CelebrationSparkSheet> createState() => _CelebrationSparkSheetState();
}

class _CelebrationSparkSheetState extends State<CelebrationSparkSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cleanGoal = widget.taskGoal.trim();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '🚀',
                    style: TextStyle(
                      fontSize: 36,
                      shadows: [
                        Shadow(
                          color: colorScheme.primary.withValues(alpha: 0.6),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '+${widget.durationMinutes}m MOMENTUM SECURED',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Flow state recorded · Every lock-in builds stamina',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (cleanGoal.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '"$cleanGoal"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const Key('celebration_roll_next_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: const Text(
                  'ROLL INTO NEXT BLOCK 🚀',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                onPressed: () {
                  unawaited(HapticFeedbackHelper.heavyImpact());
                  Navigator.of(context).pop(const CelebrationResult(rollIntoNext: true));
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                key: const Key('celebration_take_break_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  unawaited(HapticFeedbackHelper.lightClick());
                  Navigator.of(context).pop(const CelebrationResult(rollIntoNext: false));
                },
                child: const Text('TAKE A 5M BREATHER ☕'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
