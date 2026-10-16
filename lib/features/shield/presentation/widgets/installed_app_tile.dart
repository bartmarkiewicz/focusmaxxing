import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';

class InstalledAppTile extends StatelessWidget {
  const InstalledAppTile({
    super.key,
    required this.app,
    required this.onToggle,
  });

  final ShieldedAppEntity app;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBytes = app.iconBytes;

    return Semantics(
      toggled: app.isActive,
      button: true,
      label: app.appName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('installed_app_${app.packageName}'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _AppIcon(iconBytes: iconBytes),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textHighContrast,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: Checkbox(
                        value: app.isActive,
                        onChanged: (_) {},
                        activeColor: AppColors.accentLockIn,
                        checkColor: AppColors.surfaceMidnight,
                        side: const BorderSide(
                          color: AppColors.textMuted,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconBytes});

  final Uint8List? iconBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = iconBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 36,
          height: 36,
          cacheWidth: 72,
          cacheHeight: 72,
          gaplessPlayback: true,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _FallbackIcon(),
        ),
      );
    }
    return const _FallbackIcon();
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceHairline),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.android_rounded,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }
}
