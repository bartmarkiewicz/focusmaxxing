import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_banner_widget.dart';

void main() {
  Widget buildSubject({
    required ShieldPermissionStatus permissionStatus,
    required ValueChanged<ShieldPermissionType> onRequestPermission,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PermissionBannerWidget(
          permissionStatus: permissionStatus,
          onRequestPermission: onRequestPermission,
        ),
      ),
    );
  }

  group('PermissionBannerWidget', () {
    testWidgets('renders nothing when all permissions are granted',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          permissionStatus: const ShieldPermissionStatus.allGranted(),
          onRequestPermission: (_) {},
        ),
      );

      expect(find.text('SHIELD PERMISSIONS REQUIRED'), findsNothing);
    });

    testWidgets(
        'renders missing permission rows and tapping Fix Now opens guidance sheet',
        (tester) async {
      ShieldPermissionType? requested;

      await tester.pumpWidget(
        buildSubject(
          permissionStatus: const ShieldPermissionStatus(
            hasUsageStatsPermission: false,
            hasOverlayPermission: true,
            isIgnoringBatteryOptimizations: true,
          ),
          onRequestPermission: (type) {
            requested = type;
          },
        ),
      );

      expect(
        find.text('Usage access permission needed → Fix'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('fix_permission_usageStats')),
      );
      await tester.pumpAndSettle();

      // Guidance sheet should be displayed
      expect(find.text('Enable Usage Access'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_guidance_open_settings_button')),
        findsOneWidget,
      );

      // Tapping open settings in guidance sheet triggers callback
      await tester.tap(
        find.byKey(const Key('permission_guidance_open_settings_button')),
      );
      await tester.pumpAndSettle();

      expect(requested, ShieldPermissionType.usageStats);
      expect(find.text('Enable Usage Access'), findsNothing);
    });
  });
}
