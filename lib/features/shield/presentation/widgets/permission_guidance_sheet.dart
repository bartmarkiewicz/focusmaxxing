import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';

class PermissionGuidanceSheet extends StatelessWidget {
  const PermissionGuidanceSheet({
    super.key,
    required this.permissionType,
    required this.onOpenSettings,
  });

  final ShieldPermissionType permissionType;
  final VoidCallback onOpenSettings;

  static Future<void> show(
    BuildContext context, {
    required ShieldPermissionType permissionType,
    required VoidCallback onOpenSettings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PermissionGuidanceSheet(
        permissionType: permissionType,
        onOpenSettings: onOpenSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final spec = _getSpec(permissionType);

    return Container(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 32,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _GuidanceStep(
            number: '1',
            title: 'Find "Focusmaxxing"',
            subtitle: 'Scroll or search for Focusmaxxing in the Android list.',
            icon: Icons.search_rounded,
          ),
          const SizedBox(height: 12),
          _GuidanceStep(
            number: '2',
            title: 'Toggle permission to ON',
            subtitle: spec.toggleInstruction,
            icon: Icons.toggle_on_rounded,
          ),
          const SizedBox(height: 12),
          const _GuidanceStep(
            number: '3',
            title: 'Return here to Lock In',
            subtitle:
                'Focusmaxxing automatically detects the permission and arms the shield.',
            icon: Icons.verified_user_rounded,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('permission_guidance_open_settings_button'),
              onPressed: () {
                unawaited(
                  HapticFeedback.mediumImpact().catchError((Object _) {}),
                );
                Navigator.of(context).pop();
                onOpenSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: Text(
                'Open settings',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _PermissionGuidanceSpec _getSpec(ShieldPermissionType type) {
    switch (type) {
      case ShieldPermissionType.usageStats:
        return const _PermissionGuidanceSpec(
          title: 'Enable Usage Access',
          subtitle: 'Required to detect when blocked apps are opened.',
          toggleInstruction: 'Switch "Permit usage access" toggle to ON.',
          icon: Icons.query_stats_rounded,
        );
      case ShieldPermissionType.overlay:
        return const _PermissionGuidanceSpec(
          title: 'Enable Display Over Other Apps',
          subtitle: 'Required to render the full-screen Hard Lock overlay.',
          toggleInstruction:
              'Switch "Allow display over other apps" toggle to ON.',
          icon: Icons.layers_rounded,
        );
      case ShieldPermissionType.batteryOptimization:
        return const _PermissionGuidanceSpec(
          title: 'Disable Battery Optimization',
          subtitle: 'Ensures the shield stays active during long focus sessions.',
          toggleInstruction: 'Select "Unrestricted" battery usage.',
          icon: Icons.battery_charging_full_rounded,
        );
    }
  }
}

class _GuidanceStep extends StatelessWidget {
  const _GuidanceStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String number;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionGuidanceSpec {
  const _PermissionGuidanceSpec({
    required this.title,
    required this.subtitle,
    required this.toggleInstruction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String toggleInstruction;
  final IconData icon;
}
