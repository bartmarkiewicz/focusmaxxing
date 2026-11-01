import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

/// Displays rotating restorative micro-habits during a break session with zero emojis.
class BreakInfoCard extends StatefulWidget {
  const BreakInfoCard({super.key});

  static const List<({IconData icon, String title, String action})> habits = [
    (
      icon: Icons.visibility_outlined,
      title: '20-20-20 Rule',
      action:
          'Look at an object 20 feet away for 20 seconds to relax ciliary eye muscles.',
    ),
    (
      icon: Icons.water_drop_outlined,
      title: 'Hydration Check',
      action:
          'Drink a glass of water. Dehydration degrades prefrontal cortex focus.',
    ),
    (
      icon: Icons.accessibility_new_outlined,
      title: 'Physical Reset',
      action:
          'Roll shoulders back 5 times, unclench your jaw, and stand up from your chair.',
    ),
    (
      icon: Icons.air_outlined,
      title: 'Oxygen Surge',
      action:
          'Inhale deeply for 4 seconds, hold for 4, and exhale slowly for 7 seconds.',
    ),
    (
      icon: Icons.park_outlined,
      title: 'Mental Reset',
      action:
          'Step away from screens. Open a window or step outside for daylight.',
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
    final tokens = context.tokens;
    final currentHabit = BreakInfoCard.habits[_currentIndex];

    return Semantics(
      button: true,
      label:
          'Restorative tip: ${currentHabit.title}. ${currentHabit.action} Tap to see another tip.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('timer_break_info_card_tap'),
          onTap: _nextHabit,
          borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          child: Container(
            padding: const EdgeInsets.all(InstrumentTokens.s16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(InstrumentTokens.r2),
              border: Border.all(color: tokens.rule, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  currentHabit.icon,
                  size: 24,
                  color: tokens.inkMuted,
                ),
                const SizedBox(width: InstrumentTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentHabit.title,
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: InstrumentTokens.s4),
                      Text(
                        currentHabit.action,
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 13,
                          height: 18 / 13,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: InstrumentTokens.s8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: tokens.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
