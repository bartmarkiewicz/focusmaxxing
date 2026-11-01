import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
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
    final tokens = context.tokens;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _AppIcon(
                      iconBytes: iconBytes,
                      isActive: app.isActive,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: InstrumentTokens.fontUi,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: app.isActive ? tokens.ink : tokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: InstrumentTokens.fontMono,
                              fontSize: 11,
                              color: tokens.inkFaint,
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
                          activeColor: tokens.accent,
                          checkColor: tokens.accentInk,
                          side: BorderSide(
                            color: tokens.ruleStrong,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: tokens.rule,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.iconBytes,
    required this.isActive,
  });

  final Uint8List? iconBytes;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bytes = iconBytes;

    Widget iconWidget;
    if (bytes != null && bytes.isNotEmpty) {
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        child: Image.memory(
          bytes,
          width: 32,
          height: 32,
          cacheWidth: 64,
          cacheHeight: 64,
          gaplessPlayback: true,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackIcon(),
        ),
      );
    } else {
      iconWidget = const _FallbackIcon();
    }

    if (!isActive) {
      // Desaturate unblocked app icons to 80% per spec
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.8, 0.1, 0.1, 0, 0,
          0.1, 0.8, 0.1, 0, 0,
          0.1, 0.1, 0.8, 0, 0,
          0, 0, 0, 0.85, 0,
        ]),
        child: iconWidget,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      child: iconWidget,
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.rule),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.android_outlined,
        size: 18,
        color: tokens.inkMuted,
      ),
    );
  }
}
