import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';

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

    final theme = Theme.of(context);
    final missingItems = <_MissingPermissionSpec>[
      if (!permissionStatus.hasUsageStatsPermission)
        const _MissingPermissionSpec(
          type: ShieldPermissionType.usageStats,
          icon: Icons.query_stats_rounded,
          title: 'Usage Access',
          subtitle: 'Detects when blocked apps open during focus blocks.',
        ),
      if (!permissionStatus.hasOverlayPermission)
        const _MissingPermissionSpec(
          type: ShieldPermissionType.overlay,
          icon: Icons.layers_rounded,
          title: 'Display Over Other Apps',
          subtitle: 'Renders the full-screen Hard Lock Shield over distractions.',
        ),
      if (!permissionStatus.isIgnoringBatteryOptimizations)
        const _MissingPermissionSpec(
          type: ShieldPermissionType.batteryOptimization,
          icon: Icons.battery_charging_full_rounded,
          title: 'Unrestricted Battery',
          subtitle:
              'Ensures the shield never sleeps during long focus blocks.',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentHardLock.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.accentHardLock,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SHIELD PERMISSIONS REQUIRED',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.accentHardLock,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < missingItems.length; i++) ...[
            if (i > 0)
              const Divider(
                color: AppColors.surfaceHairline,
                height: 20,
              ),
            _PermissionRow(
              spec: missingItems[i],
              onFixPressed: () => onRequestPermission(missingItems[i].type),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissingPermissionSpec {
  final ShieldPermissionType type;
  final IconData icon;
  final String title;
  final String subtitle;

  const _MissingPermissionSpec({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.spec,
    required this.onFixPressed,
  });

  final _MissingPermissionSpec spec;
  final VoidCallback onFixPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          spec.icon,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHighContrast,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: OutlinedButton(
            key: ValueKey('fix_permission_${spec.type.name}'),
            onPressed: onFixPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentHardLock,
              side: const BorderSide(color: AppColors.accentHardLock),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Fix Now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
