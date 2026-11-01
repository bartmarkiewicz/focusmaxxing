import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:provider/provider.dart';

@immutable
class GoalInputResult {
  final String goal;
  final bool startImmediately;

  const GoalInputResult({
    required this.goal,
    this.startImmediately = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalInputResult &&
          runtimeType == other.runtimeType &&
          goal == other.goal &&
          startImmediately == other.startImmediately;

  @override
  int get hashCode => Object.hash(goal, startImmediately);
}

class GoalInputDialog extends StatefulWidget {
  const GoalInputDialog({
    super.key,
    required this.durationMinutes,
    this.initialGoal = '',
  });

  final int durationMinutes;
  final String initialGoal;

  static Future<String?> show(
    BuildContext context, {
    required int durationMinutes,
    String initialGoal = '',
  }) async {
    final result = await showWithAction(
      context,
      durationMinutes: durationMinutes,
      initialGoal: initialGoal,
    );
    return result?.goal;
  }

  static Future<GoalInputResult?> showWithAction(
    BuildContext context, {
    required int durationMinutes,
    String initialGoal = '',
  }) {
    return showModalBottomSheet<GoalInputResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoalInputDialog(
        durationMinutes: durationMinutes,
        initialGoal: initialGoal,
      ),
    );
  }

  @override
  State<GoalInputDialog> createState() => _GoalInputDialogState();
}

class _GoalInputDialogState extends State<GoalInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({bool startImmediately = true}) {
    final text = _controller.text.trim();
    Navigator.of(context).pop(
      GoalInputResult(
        goal: text.isNotEmpty ? text : 'Deep Work',
        startImmediately: startImmediately,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final recentGoals = context.read<TimerNotifier>().recentGoals;

    return Sheet(
      title: AppStrings.whatAreYouWorkingOn,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: tokens.ink,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.enterGoalHint,
                  hintStyle: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 18,
                    color: tokens.inkMuted,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: tokens.ruleStrong, width: 1),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: tokens.accent, width: 1.5),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(startImmediately: true),
              ),
              if (recentGoals.isNotEmpty) ...[
                const SizedBox(height: InstrumentTokens.s16),
                const SectionHeader(title: AppStrings.recent),
                const SizedBox(height: InstrumentTokens.s8),
                Wrap(
                  spacing: InstrumentTokens.s8,
                  runSpacing: InstrumentTokens.s8,
                  children: [
                    for (final goal in recentGoals)
                      Tag(
                        label: goal,
                        isSelected: _controller.text == goal,
                        onTap: () {
                          _controller.text = goal;
                          _controller.selection =
                              TextSelection.collapsed(offset: goal.length);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: InstrumentTokens.s24),
              InstrumentButton.primary(
                label: 'Start session',
                onPressed: () => _submit(startImmediately: true),
              ),
              const SizedBox(height: InstrumentTokens.s8),
              InstrumentButton.text(
                label: 'Save without starting',
                onPressed: () => _submit(startImmediately: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
