import 'dart:async';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/bring_app_to_foreground_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/start_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/stop_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/swap_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/watch_overlay_events_usecase.dart';

class _FakeShieldRepo implements IShieldRepository {
  // ignore: close_sinks
  final StreamController<dynamic> overlayController =
      StreamController<dynamic>.broadcast();

  String? lastDeactivated;
  String? lastActivated;
  String? lastActivatedName;
  bool? lastActivatedPreset;
  List<String>? lastStartedPackages;
  bool? lastStartScheduled;
  String? lastStartTimeRange;
  bool? lastStopForce;
  int bringToForegroundCalls = 0;

  @override
  Stream<dynamic> get overlayEvents => overlayController.stream;

  @override
  Future<Either<Failure, void>> swapShieldApp({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  }) async {
    lastDeactivated = deactivatePackageName;
    lastActivated = activatePackageName;
    lastActivatedName = activateAppName;
    lastActivatedPreset = activateIsPreset;
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async {
    lastStartedPackages = blockedPackages;
    lastStartScheduled = isScheduled;
    lastStartTimeRange = timeRange;
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> stopShieldService({bool force = false}) async {
    lastStopForce = force;
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> bringAppToForeground() async {
    bringToForegroundCalls++;
    return const Right(true);
  }

  @override
  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions() async =>
      const Right(ShieldPermissionStatus.allGranted());

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps() async =>
      const Right([]);

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps() async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  ) async =>
      const Right(true);

  @override
  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    bool isPaused = false,
    int? targetEndTimeEpochMs,
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, ShieldedAppEntity>> toggleShieldApp({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async =>
      throw UnimplementedError();
}

void main() {
  group('Shield Domain Use Cases', () {
    late _FakeShieldRepo repo;

    setUp(() {
      repo = _FakeShieldRepo();
    });

    tearDown(() async {
      await repo.overlayController.close();
    });

    test('SwapShieldAppUseCase validates package names and delegates to repo',
        () async {
      final useCase = SwapShieldAppUseCase(repo);

      final invalid = await useCase(
        deactivatePackageName: '   ',
        activatePackageName: 'com.reddit.frontpage',
        activateAppName: 'Reddit',
      );
      expect(invalid.isLeft(), isTrue);

      final valid = await useCase(
        deactivatePackageName: ' com.instagram.android ',
        activatePackageName: ' com.reddit.frontpage ',
        activateAppName: ' Reddit ',
        activateIsPreset: true,
      );
      expect(valid.isRight(), isTrue);
      expect(repo.lastDeactivated, 'com.instagram.android');
      expect(repo.lastActivated, 'com.reddit.frontpage');
      expect(repo.lastActivatedName, 'Reddit');
      expect(repo.lastActivatedPreset, isTrue);
    });

    test('StartShieldServiceUseCase forwards packages and schedule parameters',
        () async {
      final useCase = StartShieldServiceUseCase(repo);
      final result = await useCase(
        ['com.instagram.android'],
        isScheduled: true,
        timeRange: '09:00 - 17:00',
      );

      expect(result, const Right<Failure, bool>(true));
      expect(repo.lastStartedPackages, ['com.instagram.android']);
      expect(repo.lastStartScheduled, isTrue);
      expect(repo.lastStartTimeRange, '09:00 - 17:00');
    });

    test('StopShieldServiceUseCase forwards force parameter', () async {
      final useCase = StopShieldServiceUseCase(repo);
      final result = await useCase(force: true);

      expect(result, const Right<Failure, bool>(true));
      expect(repo.lastStopForce, isTrue);
    });

    test('BringAppToForegroundUseCase invokes repository', () async {
      final useCase = BringAppToForegroundUseCase(repo);
      final result = await useCase();

      expect(result, const Right<Failure, bool>(true));
      expect(repo.bringToForegroundCalls, 1);
    });

    test('WatchOverlayEventsUseCase exposes repository overlayEvents stream',
        () async {
      final useCase = WatchOverlayEventsUseCase(repo);
      final received = <dynamic>[];
      final sub = useCase().listen(received.add);
      addTearDown(sub.cancel);

      repo.overlayController.add({'action': 'returnToFocusmaxxing'});
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first, {'action': 'returnToFocusmaxxing'});
    });
  });
}
