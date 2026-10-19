import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_installed_apps_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_local_data_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_native_bridge_source.dart';
import 'package:focusmaxxing/features/shield/data/repositories/shield_repository_impl.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeInstalledAppsSource implements IShieldInstalledAppsSource {
  List<AppInfo> apps = [];

  @override
  Future<List<AppInfo>> getInstalledApplications() async => apps;
}

class _FakeNativeBridgeSource implements IShieldNativeBridgeSource {
  ShieldPermissionStatus permissionStatus =
      const ShieldPermissionStatus.allGranted();
  bool shieldRunning = false;
  List<String> lastStartedPackages = [];
  int stopCallCount = 0;
  int bringToForegroundCount = 0;
  Map<String, dynamic>? lastSharedOverlayPayload;
  final List<ShieldPermissionType> requestedPermissions = [];
  // ignore: close_sinks
  final StreamController<dynamic> overlayController =
      StreamController<dynamic>.broadcast();

  Future<void> dispose() => overlayController.close();

  @override
  Stream<dynamic> get overlayEvents => overlayController.stream;

  @override
  Future<ShieldPermissionStatus> checkPermissions() async => permissionStatus;

  @override
  Future<bool> requestPermission(ShieldPermissionType permissionType) async {
    requestedPermissions.add(permissionType);
    return true;
  }

  bool? lastIsScheduled;
  String? lastTimeRange;

  @override
  Future<bool> startShield(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async {
    shieldRunning = true;
    lastStartedPackages = List<String>.from(blockedPackages);
    lastIsScheduled = isScheduled;
    lastTimeRange = timeRange;
    return true;
  }

  @override
  Future<bool> stopShield() async {
    shieldRunning = false;
    stopCallCount++;
    return true;
  }

  @override
  Future<bool> isShieldRunning() async => shieldRunning;

  @override
  Future<bool> bringToForeground() async {
    bringToForegroundCount++;
    return true;
  }

  @override
  Future<void> shareOverlayData(Map<String, dynamic> payload) async {
    lastSharedOverlayPayload = payload;
  }
}

AppInfo _createAppInfo({
  required String packageName,
  required String name,
  Uint8List? icon,
}) {
  return AppInfo(
    name: name,
    icon: icon,
    packageName: packageName,
    versionName: '1.0.0',
    versionCode: 1,
    platformType: PlatformType.flutter,
    installedTimestamp: 0,
    isSystemApp: false,
    isLaunchableApp: true,
    category: AppCategory.undefined,
  );
}

void main() {
  late ShieldLocalDataSource localDataSource;
  late _FakeInstalledAppsSource installedAppsSource;
  late _FakeNativeBridgeSource nativeBridgeSource;
  late ShieldRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final runner = MigrationRunner(
      migrations: const [MigrationV1(), MigrationV2()],
    );
    await runner.run(db, oldVersion: 0, targetVersion: 2);
    DatabaseHelper.setMockDatabase(db);

    localDataSource = ShieldLocalDataSource();
    installedAppsSource = _FakeInstalledAppsSource();
    nativeBridgeSource = _FakeNativeBridgeSource();
    repository = ShieldRepositoryImpl(
      localDataSource: localDataSource,
      installedAppsSource: installedAppsSource,
      nativeBridgeSource: nativeBridgeSource,
    );
  });

  tearDown(() async {
    await nativeBridgeSource.overlayController.close();
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('ShieldRepositoryImplTest', () {
    test(
      'toggleShieldApp persists record to SQLite and getShieldedApps returns saved entities',
      () async {
        final toggleResult = await repository.toggleShieldApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isActive: true,
          isPreset: true,
        );
        expect(toggleResult.isRight(), isTrue);

        final queryResult = await repository.getShieldedApps();
        expect(queryResult.isRight(), isTrue);
        final apps = queryResult.getOrElse(() => const []);
        expect(apps.length, 1);
        expect(apps.first.packageName, 'com.instagram.android');
        expect(apps.first.appName, 'Instagram');
        expect(apps.first.isActive, isTrue);
        expect(apps.first.isPreset, isTrue);
      },
    );

    test(
      'toggleShieldApp updates native shield package list when shield service is running',
      () async {
        nativeBridgeSource.shieldRunning = true;

        await repository.toggleShieldApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isActive: true,
          isPreset: true,
        );
        expect(
          nativeBridgeSource.lastStartedPackages,
          equals(['com.instagram.android']),
        );

        await repository.toggleShieldApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isActive: true,
          isPreset: true,
        );
        expect(
          nativeBridgeSource.lastStartedPackages.toSet(),
          equals({'com.instagram.android', 'com.zhiliaoapp.musically'}),
        );

        await repository.toggleShieldApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isActive: false,
          isPreset: true,
        );
        expect(
          nativeBridgeSource.lastStartedPackages,
          equals(['com.zhiliaoapp.musically']),
        );
      },
    );

    test(
      'swapShieldApp atomically deactivates replaced app and activates new app in SQLite',
      () async {
        await repository.toggleShieldApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isActive: true,
          isPreset: true,
        );
        await repository.toggleShieldApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isActive: true,
          isPreset: true,
        );

        final swapResult = await repository.swapShieldApp(
          deactivatePackageName: 'com.instagram.android',
          activatePackageName: 'com.reddit.frontpage',
          activateAppName: 'Reddit',
          activateIsPreset: true,
        );
        expect(swapResult.isRight(), isTrue);

        final appsResult = await repository.getShieldedApps();
        final apps = appsResult.getOrElse(() => const []);
        final activePackages =
            apps.where((a) => a.isActive).map((a) => a.packageName).toSet();

        expect(
          activePackages,
          equals({'com.zhiliaoapp.musically', 'com.reddit.frontpage'}),
        );
      },
    );

    test(
      'getInstalledApps merges installed apps with SQLite state and purges uninstalled non-preset apps',
      () async {
        await repository.toggleShieldApp(
          packageName: 'com.discord',
          appName: 'Discord',
          isActive: true,
          isPreset: false,
        );
        await repository.toggleShieldApp(
          packageName: 'com.deleted.app',
          appName: 'Deleted App',
          isActive: true,
          isPreset: false,
        );

        installedAppsSource.apps = [
          _createAppInfo(packageName: 'com.discord', name: 'Discord'),
          _createAppInfo(packageName: 'com.android.chrome', name: 'Chrome'),
        ];

        final installedResult = await repository.getInstalledApps();
        expect(installedResult.isRight(), isTrue);
        final installed = installedResult.getOrElse(() => const []);
        expect(installed.length, 2);

        final discord =
            installed.firstWhere((a) => a.packageName == 'com.discord');
        final chrome =
            installed.firstWhere((a) => a.packageName == 'com.android.chrome');
        expect(discord.isActive, isTrue);
        expect(chrome.isActive, isFalse);
        expect(chrome.isPreset, isTrue);

        final savedAfterPurge =
            (await repository.getShieldedApps()).getOrElse(() => const []);
        expect(
          savedAfterPurge.any((a) => a.packageName == 'com.deleted.app'),
          isFalse,
        );
      },
    );

    test(
      'syncOverlayState and permission bridge methods delegate to nativeBridgeSource',
      () async {
        nativeBridgeSource.permissionStatus = const ShieldPermissionStatus(
          hasUsageStatsPermission: true,
          hasOverlayPermission: false,
          isIgnoringBatteryOptimizations: true,
        );

        final permResult = await repository.checkPermissions();
        expect(
          permResult.getOrElse(() => const ShieldPermissionStatus.allGranted()),
          equals(nativeBridgeSource.permissionStatus),
        );

        await repository.requestPermission(ShieldPermissionType.overlay);
        expect(
          nativeBridgeSource.requestedPermissions,
          contains(ShieldPermissionType.overlay),
        );

        await repository.syncOverlayState(
          goal: 'Ship Milestone 2',
          remainingSeconds: 900,
          isBreak: false,
        );
        expect(
          nativeBridgeSource.lastSharedOverlayPayload,
          equals({
            'goal': 'Ship Milestone 2',
            'remainingSeconds': 900,
            'isBreak': false,
            'isMaximumFocus': false,
          }),
        );
      },
    );
  });
}
