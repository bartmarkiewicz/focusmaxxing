import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/insights/presentation/widgets/session_history_list.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

void main() {
  Widget buildWidget(List<SessionEntity> sessions) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SessionHistoryList(sessions: sessions),
        ),
      ),
    );
  }

  testWidgets('renders empty placeholder when session list is empty',
      (tester) async {
    await tester.pumpWidget(buildWidget(const []));

    expect(find.text('No focus sessions recorded yet'), findsOneWidget);
    expect(
      find.text('Complete a focus session to build your momentum.'),
      findsOneWidget,
    );
  });

  testWidgets('renders session tiles with correct emojis and metadata',
      (tester) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sessions = [
      SessionEntity(
        id: 1,
        taskGoal: 'Draft architecture docs',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: nowMs,
        endTimeEpochMs: nowMs + 1500000,
        status: SessionStatus.lockedIn,
      ),
      SessionEntity(
        id: 2,
        taskGoal: 'Distracted by social feed',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1200,
        startTimeEpochMs: nowMs - 3600000,
        endTimeEpochMs: nowMs - 2400000,
        status: SessionStatus.derailed,
      ),
      SessionEntity(
        id: 3,
        taskGoal: 'Cancelled early',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 300,
        startTimeEpochMs: nowMs - 7200000,
        endTimeEpochMs: nowMs - 6900000,
        status: SessionStatus.cancelled,
      ),
    ];

    await tester.pumpWidget(buildWidget(sessions));

    expect(find.text('Draft architecture docs'), findsOneWidget);
    expect(find.text('🚀'), findsOneWidget);
    expect(find.text('Locked In'), findsOneWidget);
    expect(find.text('25m · '), findsOneWidget);

    expect(find.text('Distracted by social feed'), findsOneWidget);
    expect(find.text('💀'), findsOneWidget);
    expect(find.text('Derailed'), findsOneWidget);

    expect(find.text('Cancelled early'), findsOneWidget);
    expect(find.text('⏹️'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
