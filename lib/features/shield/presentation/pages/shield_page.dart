import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/schedule/presentation/widgets/schedule_config_section.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/installed_app_tile.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_banner_widget.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/upgrade_modal_sheet.dart';
import 'package:provider/provider.dart';

class ShieldPage extends StatefulWidget {
  const ShieldPage({super.key});

  @override
  State<ShieldPage> createState() => _ShieldPageState();
}

class _ShieldPageState extends State<ShieldPage> {
  late final TextEditingController _searchController;
  int _selectedSegment = 0;

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
              }
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
            onConfirmSwap: (deactivatePackageName) async {
              Navigator.of(sheetContext).pop();
              final success = await notifier.swapFreeApp(
                deactivatePackageName: deactivatePackageName,
                activatePackageName: packageName,
                activateAppName: appName,
              );
              if (context.mounted && !success) {
                _showErrorSnackBar(
                  context,
                  notifier.errorMessage ?? 'Unable to swap shielded app.',
                );
              }
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final notifier = context.watch<ShieldNotifier?>();
    final isScanning = notifier?.isLoading ?? false;
    final filteredApps = notifier?.filteredInstalledApps ?? [];
    final activeCount = notifier?.activeAppCount ?? 0;
    final query = notifier?.searchQuery ?? '';

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppStrings.shieldTitle,
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isExpanded = constraints.maxWidth >= 600;

            final presetsSection = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notifier != null && !notifier.permissionStatus.isAllGranted)
                  PermissionBannerWidget(
                    permissionStatus: notifier.permissionStatus,
                    onRequestPermission: (type) {
                      unawaited(notifier.requestPermission(type));
                    },
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Tag(
                        label: 'Apps ($activeCount)',
                        isSelected: _selectedSegment == 0,
                        onTap: () => setState(() => _selectedSegment = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tag(
                        label: 'Schedule',
                        isSelected: _selectedSegment == 1,
                        onTap: () => setState(() => _selectedSegment = 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_selectedSegment == 0) ...[
                  const SectionHeader(title: AppStrings.presets),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ShieldPreset.defaults.map((preset) {
                      final isSelected =
                          notifier?.isPackageActive(preset.packageName) ?? false;
                      return KeyedSubtree(
                        key: ValueKey('preset_${preset.packageName}'),
                        child: Tag(
                          label: preset.appName,
                          isSelected: isSelected,
                          onTap: () {
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
                      );
                    }).toList(),
                  ),
                ],
              ],
            );

            final searchAndAppsSection = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: AppStrings.appsBlockedHeader(activeCount)),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('shield_app_search_field'),
                  controller: _searchController,
                  onChanged: (val) => notifier?.setSearchQuery(val),
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 15,
                    color: tokens.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchAppsHint,
                    prefixIcon: Icon(Icons.search_outlined, size: 20, color: tokens.inkMuted),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_outlined, size: 18, color: tokens.inkMuted),
                            onPressed: () {
                              _searchController.clear();
                              notifier?.setSearchQuery('');
                            },
                          )
                        : null,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tokens.ruleStrong, width: 1),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tokens.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isScanning)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Scanning installed apps...',
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 14,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                  )
                else if (filteredApps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        query.trim().isNotEmpty
                            ? 'No apps matching "$query"'
                            : 'No third-party apps detected',
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 14,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                  )
                else
                  for (final app in filteredApps)
                    InstalledAppTile(
                      app: app,
                      onToggle: () {
                        if (notifier != null) {
                          unawaited(
                            _handleToggleApp(
                              context,
                              notifier,
                              packageName: app.packageName,
                              appName: app.appName,
                              isPreset: app.isPreset,
                              iconBytes: app.iconBytes,
                            ),
                          );
                        }
                      },
                    ),
              ],
            );

            if (_selectedSegment == 1) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  presetsSection,
                  const SizedBox(height: 16),
                  const ScheduleConfigSection(),
                ],
              );
            }

            if (isExpanded) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: presetsSection,
                        ),
                      ),
                      Container(width: 1, color: tokens.rule),
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: searchAndAppsSection,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                presetsSection,
                const SizedBox(height: 16),
                searchAndAppsSection,
              ],
            );
          },
        ),
      ),
    );
  }
}
