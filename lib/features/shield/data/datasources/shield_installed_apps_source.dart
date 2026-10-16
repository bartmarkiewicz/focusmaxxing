import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/installed_apps.dart';

abstract interface class IShieldInstalledAppsSource {
  Future<List<AppInfo>> getInstalledApplications();
}

class ShieldInstalledAppsSourceImpl implements IShieldInstalledAppsSource {
  const ShieldInstalledAppsSourceImpl();

  @override
  Future<List<AppInfo>> getInstalledApplications() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const [];
    }
    try {
      return await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: true,
        detectPlatformType: false,
      );
    } catch (_) {
      return const [];
    }
  }
}
