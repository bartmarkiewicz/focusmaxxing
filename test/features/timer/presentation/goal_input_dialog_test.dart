import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_input_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepository implements ISessionRepository {
  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right<Failure, List<SessionEntity>>([]);
}

class _MockNotificationService extends NotificationService {
  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
    bool isBreak = false,
  }) async {}

  @override
  Future<void> cancelTimerNotification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimerNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TimerNotifier.recentGoalsKey: <String>['Write Docs', 'Review PR'],
    });
    final prefs = await SharedPreferences.getInstance();

    final repo = _FakeSessionRepository();
    notifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(repo),
      completeSessionUseCase: CompleteSessionUseCase(repo),
      cancelSessionUseCase: CancelSessionUseCase(repo),
      notificationService: _MockNotificationService(),
      prefs: prefs,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  Widget buildDialog() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerNotifier>.value(value: notifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: GoalInputDialog(durationMinutes: 25),
        ),
      ),
    );
  }

  group('GoalInputDialog', () {
    testWidgets('renders prompt, textfield, and quick chips', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(
          find.text('What ONE thing are you locking in on?'), findsOneWidget);
      expect(find.text('⚡ Deep Work'), findsOneWidget);
      expect(find.text('Write Docs'), findsOneWidget);
      expect(find.text('Review PR'), findsOneWidget);
      expect(find.text('START FOCUS (25m)'), findsOneWidget);
    });

    testWidgets(
        'tapping recent goal chip auto-fills text and positions cursor at end',
        (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write Docs'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Write Docs');
      expect(
        textField.controller?.selection.baseOffset,
        'Write Docs'.length,
      );
    });
  });
}
