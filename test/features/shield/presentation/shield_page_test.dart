import 'dart:async';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/pages/shield_page.dart';
import 'package:focusmaxxing/features/schedule/presentation/widgets/schedule_config_section.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_banner_widget.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/upgrade_modal_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestShieldRepository implements IShieldRepository {
  final Map<String, ShieldedAppEntity> savedApps = {};
  List<ShieldedAppEntity> installedApps = [
    ShieldedAppEntity(
      packageName: 'com.discord',
      appName: 'Discord',
      isActive: false,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
    ShieldedAppEntity(
      packageName: 'com.spotify.music',
      appName: 'Spotify',
      isActive: false,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
  ];
  ShieldPermissionStatus permissionStatus =
      const ShieldPermissionStatus.allGranted();
  final List<ShieldPermissionType> requestedPermissions = [];

  @override
  Stream<dynamic> get overlayEvents => const Stream.empty();

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps() async =>
      Right(savedApps.values.toList());

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps() async =>
      Right(installedApps);

  @override
  Future<Either<Failure, ShieldedAppEntity>> toggleShieldApp({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async {
    final entity = ShieldedAppEntity(
      packageName: packageName,
      appName: appName,
      iconBytes: iconBytes,
      isActive: isActive,
      isPreset: isPreset,
      createdAt: DateTime.utc(2026, 10, 16),
    );
    savedApps[packageName] = entity;
    return Right(entity);
  }

  @override
  Future<Either<Failure, void>> swapShieldApp({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  }) async {
    final old = savedApps[deactivatePackageName];
    if (old != null) {
      savedApps[deactivatePackageName] = old.copyWith(isActive: false);
    }
    savedApps[activatePackageName] = ShieldedAppEntity(
      packageName: activatePackageName,
      appName: activateAppName,
      isActive: true,
      isPreset: activateIsPreset,
      createdAt: DateTime.utc(2026, 10, 16),
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions() async =>
      Right(permissionStatus);

  @override
  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  ) async {
    requestedPermissions.add(permissionType);
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async =>
      const Right(true);

  @override
  Future<Either<Failure, bool>> stopShieldService() async => const Right(true);

  @override
  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    int? targetEndTimeEpochMs,
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, bool>> bringAppToForeground() async =>
      const Right(true);
}

void main() {
  late _TestShieldRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _TestShieldRepository();
  });

  Future<ShieldNotifier> createInitializedNotifier() async {
    final notifier = ShieldNotifier(
      getShieldedAppsUseCase: GetShieldedAppsUseCase(repository),
      getInstalledAppsUseCase: GetInstalledAppsUseCase(repository),
      toggleShieldAppUseCase: ToggleShieldAppUseCase(repository),
      checkShieldPermissionsUseCase: CheckShieldPermissionsUseCase(repository),
      requestPermissionUseCase: RequestPermissionUseCase(repository),
      syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(repository),
      repository: repository,
      sharedPreferences: prefs,
      autoInitialize: false,
    );
    await notifier.refresh();
    return notifier;
  }

  Widget buildSubject(ShieldNotifier notifier) {
    return ChangeNotifierProvider<ShieldNotifier>.value(
      value: notifier,
      child: MaterialApp(
        theme: AppTheme.buildDarkTheme(null),
        home: const ShieldPage(),
      ),
    );
  }

  group('ShieldPageTest', () {
    testWidgets(
      'shows PermissionBannerWidget with Fix Now when permissions are missing',
      (tester) async {
        repository.permissionStatus = const ShieldPermissionStatus(
          hasUsageStatsPermission: false,
          hasOverlayPermission: true,
          isIgnoringBatteryOptimizations: true,
        );
        final notifier = await createInitializedNotifier();

        await tester.pumpWidget(buildSubject(notifier));
        await tester.pumpAndSettle();

        expect(find.byType(PermissionBannerWidget), findsOneWidget);
        expect(find.text('Usage Access'), findsOneWidget);
        expect(find.text('Fix Now'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('fix_permission_usageStats')),
        );
        await tester.pumpAndSettle();

        expect(
          repository.requestedPermissions,
          contains(ShieldPermissionType.usageStats),
        );
      },
    );

    testWidgets(
      'hides PermissionBannerWidget when all permissions are granted',
      (tester) async {
        repository.permissionStatus = const ShieldPermissionStatus.allGranted();
        final notifier = await createInitializedNotifier();

        await tester.pumpWidget(buildSubject(notifier));
        await tester.pumpAndSettle();

        expect(find.byType(PermissionBannerWidget), findsNothing);
        expect(find.text('Fix Now'), findsNothing);
      },
    );

    testWidgets(
      'tapping Quick-Preset cards updates selection state and opens UpgradeModalSheet on 3rd selection',
      (tester) async {
        final notifier = await createInitializedNotifier();

        await tester.pumpWidget(buildSubject(notifier));
        await tester.pumpAndSettle();

        expect(
          find.text('Shield Status: READY (0/2 Apps Selected)'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('preset_com.instagram.android')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Shield Status: ACTIVE (1/2 Apps Selected)'),
          findsOneWidget,
        );
        expect(notifier.isPackageActive('com.instagram.android'), isTrue);

        await tester.tap(
          find.byKey(const ValueKey('preset_com.zhiliaoapp.musically')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Shield Status: ACTIVE (2/2 Apps Selected)'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('preset_com.reddit.frontpage')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UpgradeModalSheet), findsOneWidget);
      },
    );

    testWidgets(
      'entering text in app search bar filters installed apps in real-time',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = await createInitializedNotifier();

        await tester.pumpWidget(buildSubject(notifier));
        await tester.pumpAndSettle();

        expect(find.text('Discord'), findsOneWidget);
        expect(find.text('Spotify'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('shield_app_search_field')),
          'Disc',
        );
        await tester.pumpAndSettle();

        expect(find.text('Discord'), findsOneWidget);
        expect(find.text('Spotify'), findsNothing);
      },
    );

    testWidgets(
      'switches between Apps and Schedule tabs using segmented button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final notifier = await createInitializedNotifier();

        await tester.pumpWidget(buildSubject(notifier));
        await tester.pumpAndSettle();

        expect(find.text('QUICK PRESETS'), findsOneWidget);

        // Tap Schedule tab
        await tester.tap(find.text('Schedule'));
        await tester.pumpAndSettle();

        expect(find.text('QUICK PRESETS'), findsNothing);
        expect(find.byType(ScheduleConfigSection), findsOneWidget);

        // Tap Apps tab
        await tester.tap(find.byIcon(Icons.shield_outlined));
        await tester.pumpAndSettle();

        expect(find.text('QUICK PRESETS'), findsOneWidget);
        expect(find.byType(ScheduleConfigSection), findsNothing);
      },
    );
  });
}
