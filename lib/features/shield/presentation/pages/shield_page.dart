import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/installed_app_tile.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_banner_widget.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/quick_preset_card.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/upgrade_modal_sheet.dart';
import 'package:provider/provider.dart';

class ShieldPage extends StatefulWidget {
  const ShieldPage({super.key});

  @override
  State<ShieldPage> createState() => _ShieldPageState();
}

class _ShieldPageState extends State<ShieldPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.accentHardLock,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _handleToggleApp(
    BuildContext context,
    ShieldNotifier notifier, {
    required String packageName,
    required String appName,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async {
    final result = await notifier.toggleApp(
      packageName: packageName,
      appName: appName,
      isPreset: isPreset,
      iconBytes: iconBytes,
    );

    if (!context.mounted) return;

    if (result == ShieldToggleResult.failed) {
      _showErrorSnackBar(
        context,
        notifier.errorMessage ?? 'Unable to update app shield.',
      );
      return;
    }

    if (result == ShieldToggleResult.upgradeRequired) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return UpgradeModalSheet(
            activeApps: notifier.activeShieldedApps,
            candidateAppName: appName,
            onUnlockPro: () async {
              final billingNotifier = context.read<BillingNotifier?>();
              if (billingNotifier != null) {
                await billingNotifier.buyLifetimePro();
              } else {
                await notifier.unlockLifetimePro();
              }
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
            onConfirmSwap: (deactivatePackageName) async {
              final swapped = await notifier.swapFreeApp(
                deactivatePackageName: deactivatePackageName,
              );
              if (swapped) {
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              } else if (context.mounted) {
                _showErrorSnackBar(
                  context,
                  notifier.errorMessage ?? 'Unable to swap shielded app.',
                );
              }
            },
          );
        },
      );
      notifier.dismissUpgradePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = context.watch<ShieldNotifier?>();
    final permissionStatus = notifier?.permissionStatus;
    final hasAllPermissions = permissionStatus?.isAllGranted ?? true;
    final query = notifier?.searchQuery ?? '';
    final filteredApps = notifier?.filteredInstalledApps ?? const [];
    final isScanning =
        (notifier?.isLoading ?? false) &&
        (notifier?.allInstalledApps.isEmpty ?? true);

    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Brainrot Shield',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: ProSupporterBadge()),
          ),
        ],
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.accentLockIn,
        onRefresh: () async {
          if (notifier != null) {
            await notifier.refresh();
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverList.list(
                children: [
                  if (notifier != null && !hasAllPermissions) ...[
                    PermissionBannerWidget(
                      permissionStatus: notifier.permissionStatus,
                      onRequestPermission: (type) {
                        unawaited(notifier.requestPermission(type));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ShieldStatusBanner(
                    activeCount: notifier?.activeAppCount ?? 0,
                    isPro: notifier?.isPro ?? false,
                  ),
                  const SizedBox(height: 20),
                  const _SectionHeader(title: 'QUICK PRESETS'),
                  const SizedBox(height: 10),
                  _QuickPresetsGrid(
                    notifier: notifier,
                    onPresetTap: (preset) {
                      if (notifier != null) {
                        unawaited(
                          _handleToggleApp(
                            context,
                            notifier,
                            packageName: preset.packageName,
                            appName: preset.appName,
                            isPreset: true,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'ALL INSTALLED APPS'),
                  const SizedBox(height: 10),
                  _AppSearchBar(
                    controller: _searchController,
                    query: query,
                    onChanged: (value) => notifier?.setSearchQuery(value),
                    onClear: () {
                      _searchController.clear();
                      notifier?.setSearchQuery('');
                    },
                  ),
                ],
              ),
            ),
            if (notifier == null)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else if (isScanning)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _EmptyInstalledAppsCard(
                    message: 'Scanning installed apps...',
                  ),
                ),
              )
            else if (filteredApps.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _EmptyInstalledAppsCard(
                    message: query.trim().isNotEmpty
                        ? 'No matching apps found for "$query".'
                        : 'No third-party launchable apps detected.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: DecoratedSliver(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceHairline),
                  ),
                  sliver: SliverList.separated(
                    itemCount: filteredApps.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: AppColors.surfaceHairline,
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                    ),
                    itemBuilder: (itemContext, index) {
                      final app = filteredApps[index];
                      return InstalledAppTile(
                        app: app,
                        onToggle: () {
                          unawaited(
                            _handleToggleApp(
                              itemContext,
                              notifier,
                              packageName: app.packageName,
                              appName: app.appName,
                              isPreset: app.isPreset,
                              iconBytes: app.iconBytes,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              sliver: SliverList.list(
                children: const [
                  LifetimeProBanner(),
                  SizedBox(height: 24),
                  _SectionHeader(title: 'PROTECTION RULES'),
                  SizedBox(height: 10),
                  _RulesCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ShieldStatusBanner extends StatelessWidget {
  const _ShieldStatusBanner({
    required this.activeCount,
    required this.isPro,
  });

  final int activeCount;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusTitle = isPro
        ? 'Shield Status: PRO UNLOCKED ($activeCount Apps Selected)'
        : 'Shield Status: ${activeCount > 0 ? "ACTIVE" : "READY"} ($activeCount/${ShieldNotifier.freeTierAppCap} Apps Selected)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Text(
              '🛡️',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Physically intercepts addictive feeds during focus blocks and restorative breaks.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPresetsGrid extends StatelessWidget {
  const _QuickPresetsGrid({
    required this.notifier,
    required this.onPresetTap,
  });

  final ShieldNotifier? notifier;
  final ValueChanged<ShieldPreset> onPresetTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ShieldPreset.defaults.map((preset) {
        final isSelected =
            notifier?.isPackageActive(preset.packageName) ?? false;
        return QuickPresetCard(
          preset: preset,
          isSelected: isSelected,
          onTap: () => onPresetTap(preset),
        );
      }).toList(),
    );
  }
}

class _AppSearchBar extends StatelessWidget {
  const _AppSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('shield_app_search_field'),
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textHighContrast),
      decoration: InputDecoration(
        hintText: 'Search apps...',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
        ),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentLockIn),
        ),
      ),
    );
  }
}

class _EmptyInstalledAppsCard extends StatelessWidget {
  const _EmptyInstalledAppsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _RuleItem(
              icon: Icons.block_rounded,
              title: 'Zero Bypass During Sessions',
              subtitle:
                  'No emergency pass or snooze options. Tapping overlay returns directly to Focusmaxxing.',
            ),
            Divider(color: colorScheme.outlineVariant, height: 20),
            const _RuleItem(
              icon: Icons.nightlife_rounded,
              title: 'Restorative Break Guard',
              subtitle:
                  'Apps remain locked through the 5-minute break until you explicitly lock in on your next block.',
            ),
            Divider(color: colorScheme.outlineVariant, height: 20),
            const _RuleItem(
              icon: Icons.shield_moon_outlined,
              title: 'Native Android Service',
              subtitle:
                  'Engineered with UsageStatsManager and SYSTEM_ALERT_WINDOW (Milestone 2 native engine).',
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
