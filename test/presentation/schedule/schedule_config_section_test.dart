import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:focusmaxxing/features/schedule/presentation/widgets/schedule_config_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeScheduleRepository implements IScheduleRepository {
  ScheduleConfigEntity schedule = ScheduleConfigEntity.initial;

  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async =>
      Right(schedule);

  @override
  Future<Either<Failure, void>> saveSchedule(ScheduleConfigEntity s) async {
    schedule = s;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> armAlarms(ScheduleConfigEntity s) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> cancelAlarms() async => const Right(null);

  @override
  Future<Either<Failure, bool>> isScheduleActiveNow() async =>
      Right(schedule.isEnabled);
}

void main() {
  group('ScheduleConfigSection Widget Tests', () {
    late FakeScheduleRepository repository;
    late ScheduleNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({'is_lifetime_pro': false});
      repository = FakeScheduleRepository();
      notifier = ScheduleNotifier(
        getScheduleUseCase: GetScheduleUseCase(repository),
        saveScheduleUseCase: SaveScheduleUseCase(repository),
        toggleAutoShieldUseCase: ToggleAutoShieldUseCase(repository),
        repository: repository,
        autoInitialize: false,
      );
    });

    Widget buildTestWidget(
        {ScheduleNotifier? customNotifier, bool? isProUnlocked}) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider<ScheduleNotifier>.value(
              value: customNotifier ?? notifier,
              child: ScheduleConfigSection(
                notifier: customNotifier ?? notifier,
                isProUnlocked: isProUnlocked,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders title, master switch, time buttons, and weekday chips',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Scheduled Auto-Shield'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('schedule_master_switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule_start_time_btn')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('schedule_end_time_btn')), findsOneWidget);

      // Verify all 7 weekday chips are rendered
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets(
        'renders PRO badge when isProUnlocked is false and shows pro gate banner on toggle',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(isProUnlocked: false));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('schedule_pro_badge')), findsOneWidget);

      // Tapping switch without Pro triggers pro prompt
      await tester.tap(find.byKey(const ValueKey('schedule_master_switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('schedule_pro_gate_banner')),
          findsOneWidget);
      expect(
        find.text('Scheduled Auto-Shield is a Lifetime Pro feature.'),
        findsOneWidget,
      );
    });

    testWidgets('toggling weekday chip updates selection in notifier',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Saturday is initially unselected
      expect(notifier.activeDays.contains(DateTime.saturday), isFalse);

      // Tap Sat chip
      await tester.tap(find.byKey(const ValueKey('weekday_chip_6')));
      await tester.pumpAndSettle();

      expect(notifier.activeDays.contains(DateTime.saturday), isTrue);

      // Tap Sat chip again to deselect
      await tester.tap(find.byKey(const ValueKey('weekday_chip_6')));
      await tester.pumpAndSettle();

      expect(notifier.activeDays.contains(DateTime.saturday), isFalse);
    });

    testWidgets('tapping start time button opens TimePicker dialog',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('schedule_start_time_btn')));
      await tester.pumpAndSettle();

      // TimePicker dialog should be present
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Tap Cancel to dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets(
        'displays error banner when errorMessage is present and dismisses on tap',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Cause a validation error (e.g. setting start time after end time)
      await notifier.setStartTime(18, 0);
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('schedule_error_banner')), findsOneWidget);
      expect(find.text('Start time must precede end time'), findsOneWidget);

      // Tap clear error button
      await tester.tap(find.byTooltip('Clear error'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('schedule_error_banner')), findsNothing);
    });
  });
}
