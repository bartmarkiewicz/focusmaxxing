import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_installed_apps_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_local_data_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_native_bridge_source.dart';
import 'package:focusmaxxing/features/shield/data/models/shielded_app_model.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class ShieldRepositoryImpl implements IShieldRepository {
  final IShieldLocalDataSource localDataSource;
  final IShieldInstalledAppsSource installedAppsSource;
  final IShieldNativeBridgeSource nativeBridgeSource;

  const ShieldRepositoryImpl({
    required this.localDataSource,
    required this.installedAppsSource,
    required this.nativeBridgeSource,
  });

  @override
  Stream<dynamic> get overlayEvents => nativeBridgeSource.overlayEvents;

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps() async {
    try {
      final models = await localDataSource.getShieldedApps();
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(
          DatabaseFailure('Unexpected error loading shielded apps: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps() async {
    try {
      final installedInfos =
          await installedAppsSource.getInstalledApplications();
      final savedModels = await localDataSource.getShieldedApps();
      final savedByPackage = <String, ShieldedAppModel>{
        for (final model in savedModels) model.packageName: model,
      };

      if (installedInfos.isNotEmpty) {
        final installedPackages =
            installedInfos.map((info) => info.packageName).toSet();
        await localDataSource.purgeUninstalledApps(installedPackages);
      }

      final presetPackages = {
        for (final preset in ShieldPreset.defaults) preset.packageName,
      };

      final now = DateTime.now().toUtc();
      final entities = installedInfos.map((info) {
        final saved = savedByPackage[info.packageName];
        return ShieldedAppEntity(
          packageName: info.packageName,
          appName: info.name,
          iconBytes: info.icon,
          isActive: saved?.isActive ?? false,
          isPreset:
              saved?.isPreset ?? presetPackages.contains(info.packageName),
          createdAt: saved?.createdAt ?? now,
        );
      }).toList();

      return Right(entities);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(
        PlatformFailure('Failed to discover installed applications: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, ShieldedAppEntity>> toggleShieldApp({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async {
    try {
      final model = ShieldedAppModel(
        packageName: packageName,
        appName: appName,
        iconBytes: iconBytes,
        isActive: isActive,
        isPreset: isPreset,
        createdAt: DateTime.now().toUtc(),
      );
      await localDataSource.upsertShieldedApp(model);
      await _refreshNativeShieldIfRunning();
      return Right(model.toEntity());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure('Unexpected error toggling app shield: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> swapShieldApp({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  }) async {
    try {
      final activateModel = ShieldedAppModel(
        packageName: activatePackageName,
        appName: activateAppName,
        isActive: true,
        isPreset: activateIsPreset,
        createdAt: DateTime.now().toUtc(),
      );
      await localDataSource.swapShieldedApp(
        deactivatePackageName: deactivatePackageName,
        activateApp: activateModel,
      );
      await _refreshNativeShieldIfRunning();
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(
          DatabaseFailure('Unexpected error swapping shielded app: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  ) async {
    try {
      await localDataSource.purgeUninstalledApps(installedPackages);
      await _refreshNativeShieldIfRunning();
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(
        DatabaseFailure('Unexpected error purging uninstalled apps: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions() async {
    try {
      final status = await nativeBridgeSource.checkPermissions();
      return Right(status);
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(PlatformFailure('Unexpected error checking permissions: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  ) async {
    try {
      final granted =
          await nativeBridgeSource.requestPermission(permissionType);
      return Right(granted);
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(
        PlatformFailure('Unexpected error requesting permission: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async {
    try {
      final started = await nativeBridgeSource.startShield(
        blockedPackages,
        isScheduled: isScheduled,
        timeRange: timeRange,
      );
      return Right(started);
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(PlatformFailure('Unexpected error starting shield: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> stopShieldService() async {
    try {
      final stopped = await nativeBridgeSource.stopShield();
      return Right(stopped);
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } catch (e) {
      return Left(PlatformFailure('Unexpected error stopping shield: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    int? targetEndTimeEpochMs,
  }) async {
    try {
      await nativeBridgeSource.shareOverlayData(<String, dynamic>{
        'goal': goal,
        'remainingSeconds': remainingSeconds,
        'isBreak': isBreak,
        'isMaximumFocus': isMaximumFocus,
        if (targetEndTimeEpochMs != null)
          'targetEndTimeEpochMs': targetEndTimeEpochMs,
      });
      return const Right(null);
    } catch (e) {
      return Left(PlatformFailure('Failed to sync overlay state: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> bringAppToForeground() async {
    try {
      final result = await nativeBridgeSource.bringToForeground();
      return Right(result);
    } catch (e) {
      return Left(PlatformFailure('Failed to bring app to foreground: $e'));
    }
  }

  Future<void> _refreshNativeShieldIfRunning() async {
    final running = await nativeBridgeSource.isShieldRunning();
    if (!running) return;

    final activeApps = await localDataSource.getActiveShieldedApps();
    final activePackages = activeApps.map((a) => a.packageName).toList();
    if (activePackages.isEmpty) {
      await nativeBridgeSource.stopShield();
    } else {
      await nativeBridgeSource.startShield(activePackages);
    }
  }
}
