import 'package:equatable/equatable.dart';

enum ShieldPermissionType {
  usageStats,
  overlay,
  batteryOptimization,
}

class ShieldPermissionStatus extends Equatable {
  final bool hasUsageStatsPermission;
  final bool hasOverlayPermission;
  final bool isIgnoringBatteryOptimizations;

  const ShieldPermissionStatus({
    required this.hasUsageStatsPermission,
    required this.hasOverlayPermission,
    required this.isIgnoringBatteryOptimizations,
  });

  const ShieldPermissionStatus.allGranted()
      : hasUsageStatsPermission = true,
        hasOverlayPermission = true,
        isIgnoringBatteryOptimizations = true;

  const ShieldPermissionStatus.noneGranted()
      : hasUsageStatsPermission = false,
        hasOverlayPermission = false,
        isIgnoringBatteryOptimizations = false;

  bool get isCoreGranted => hasUsageStatsPermission && hasOverlayPermission;

  bool get isAllGranted =>
      hasUsageStatsPermission &&
      hasOverlayPermission &&
      isIgnoringBatteryOptimizations;

  ShieldPermissionStatus copyWith({
    bool? hasUsageStatsPermission,
    bool? hasOverlayPermission,
    bool? isIgnoringBatteryOptimizations,
  }) {
    return ShieldPermissionStatus(
      hasUsageStatsPermission:
          hasUsageStatsPermission ?? this.hasUsageStatsPermission,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      isIgnoringBatteryOptimizations:
          isIgnoringBatteryOptimizations ?? this.isIgnoringBatteryOptimizations,
    );
  }

  @override
  List<Object?> get props => [
        hasUsageStatsPermission,
        hasOverlayPermission,
        isIgnoringBatteryOptimizations,
      ];
}
