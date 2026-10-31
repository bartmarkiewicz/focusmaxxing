import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays rotating restorative micro-habits during a break session.
class BreakInfoCard extends StatefulWidget {
  const BreakInfoCard({super.key});

  static const List<({String icon, String title, String action})> habits = [
    (
      icon: '👁️',
      title: '20-20-20 Rule',
      action:
          'Look at an object 20 feet away for 20 seconds to relax ciliary eye muscles.',
    ),
    (
      icon: '💧',
      title: 'Hydration Check',
      action:
          'Drink 1 full glass of cold water now. Dehydration degrades prefrontal focus.',
    ),
    (
      icon: '🧘',
      title: 'Physical Reset',
      action:
          'Roll shoulders back 5 times, unclench your jaw, and stand up from your chair.',
    ),
    (
      icon: '🫁',
      title: 'Oxygen Surge',
      action:
          'Inhale deeply for 4 seconds, hold for 4, and exhale slowly for 7 seconds.',
    ),
    (
      icon: '🌿',
      title: 'Mental Reset',
      action:
          'Step away from screens. Open a window or step outside for fresh air and daylight.',
    ),
  ];

  @override
  State<BreakInfoCard> createState() => _BreakInfoCardState();
}

class _BreakInfoCardState extends State<BreakInfoCard> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = DateTime.now().minute % BreakInfoCard.habits.length;
  }

  void _nextHabit() {
    unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
    setState(() {
      _currentIndex = (_currentIndex + 1) % BreakInfoCard.habits.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final habit = BreakInfoCard.habits[_currentIndex];

    return Semantics(
      button: true,
      label:
          'Restorative habit: ${habit.title}. ${habit.action}. Double tap to shuffle habit.',
      child: InkWell(
        key: const Key('timer_break_info_card_tap'),
        onTap: _nextHabit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(habit.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Tap to shuffle 🔀',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                habit.action,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Social feeds remain locked during break',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
