import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';

abstract interface class IShieldRepository {
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps();

  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps();

  Future<Either<Failure, ShieldedAppEntity>> toggleShieldApp({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  });

  Future<Either<Failure, void>> swapShieldApp({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  });

  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  );

  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions();

  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  );

  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  });

  Future<Either<Failure, bool>> stopShieldService({bool force = false});

  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    bool isPaused = false,
    int? targetEndTimeEpochMs,
  });

  Future<Either<Failure, bool>> bringAppToForeground();

  Stream<dynamic> get overlayEvents;
}
