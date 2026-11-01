import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_guidance_sheet.dart';

class PermissionBannerWidget extends StatelessWidget {
  const PermissionBannerWidget({
    super.key,
    required this.permissionStatus,
    required this.onRequestPermission,
  });

  final ShieldPermissionStatus permissionStatus;
  final ValueChanged<ShieldPermissionType> onRequestPermission;

  @override
  Widget build(BuildContext context) {
    if (permissionStatus.isAllGranted) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;

    final missingSpec = !permissionStatus.hasUsageStatsPermission
        ? (
            type: ShieldPermissionType.usageStats,
            label: 'Usage access permission needed → Fix',
          )
        : (!permissionStatus.hasOverlayPermission
            ? (
                type: ShieldPermissionType.overlay,
                label: 'Overlay permission needed → Fix',
              )
            : (
                type: ShieldPermissionType.batteryOptimization,
                label: 'Battery optimization exemption needed → Fix',
              ));

    return Padding(
      padding: const EdgeInsets.only(bottom: InstrumentTokens.s12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('fix_permission_${missingSpec.type.name}'),
          borderRadius: BorderRadius.circular(InstrumentTokens.r1),
          onTap: () {
            unawaited(
              PermissionGuidanceSheet.show(
                context,
                permissionType: missingSpec.type,
                onOpenSettings: () => onRequestPermission(missingSpec.type),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InstrumentTokens.s16,
              vertical: InstrumentTokens.s12,
            ),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(InstrumentTokens.r1),
              border: Border.all(color: tokens.danger, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: tokens.danger,
                ),
                const SizedBox(width: InstrumentTokens.s12),
                Expanded(
                  child: Text(
                    missingSpec.label,
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
