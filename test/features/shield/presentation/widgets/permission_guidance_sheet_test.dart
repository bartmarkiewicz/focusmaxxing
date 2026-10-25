import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_guidance_sheet.dart';

void main() {
  Widget buildSubject({
    required ShieldPermissionType permissionType,
    required VoidCallback onOpenSettings,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              unawaited(
                PermissionGuidanceSheet.show(
                  context,
                  permissionType: permissionType,
                  onOpenSettings: onOpenSettings,
                ),
              );
            },
            child: const Text('SHOW SHEET'),
          ),
        ),
      ),
    );
  }

  group('PermissionGuidanceSheet', () {
    testWidgets('renders usage stats guidance steps and triggers callback',
        (tester) async {
      var settingsOpened = false;

      await tester.pumpWidget(
        buildSubject(
          permissionType: ShieldPermissionType.usageStats,
          onOpenSettings: () {
            settingsOpened = true;
          },
        ),
      );

      await tester.tap(find.text('SHOW SHEET'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Usage Access'), findsOneWidget);
      expect(
        find.text('Required to detect when blocked apps are opened.'),
        findsOneWidget,
      );
      expect(find.text('Find "Focusmaxxing"'), findsOneWidget);
      expect(find.text('Toggle permission to ON'), findsOneWidget);
      expect(
        find.text('Switch "Permit usage access" toggle to ON.'),
        findsOneWidget,
      );
      expect(find.text('Return here to Lock In'), findsOneWidget);
      expect(
        find.byKey(const Key('permission_guidance_open_settings_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('permission_guidance_open_settings_button')),
      );
      await tester.pumpAndSettle();

      expect(settingsOpened, isTrue);
      expect(find.text('Enable Usage Access'), findsNothing);
    });

    testWidgets('renders overlay permission guidance correctly', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          permissionType: ShieldPermissionType.overlay,
          onOpenSettings: () {},
        ),
      );

      await tester.tap(find.text('SHOW SHEET'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Display Over Other Apps'), findsOneWidget);
      expect(
        find.text('Switch "Allow display over other apps" toggle to ON.'),
        findsOneWidget,
      );
    });

    testWidgets('renders battery optimization guidance correctly',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          permissionType: ShieldPermissionType.batteryOptimization,
          onOpenSettings: () {},
        ),
      );

      await tester.tap(find.text('SHOW SHEET'));
      await tester.pumpAndSettle();

      expect(find.text('Disable Battery Optimization'), findsOneWidget);
      expect(
        find.text('Select "Unrestricted" battery usage.'),
        findsOneWidget,
      );
    });
  });
}
